#!/usr/bin/env bash
# Script Purpose: Validate port policy for this build repo.
# Usage: Run on host: ./scripts/check-internal-ports-policy.sh (fails non-zero on policy violation).
# Behavior:
# 1) If compose file exists, enforce "only allowed services may publish host ports".
# 2) If compose file does not exist (current repo mode), enforce Dockerfile/Apache port contract.
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

normalize_list() {
  local raw="${1:-}"
  echo "${raw}" | tr ',' ' ' | xargs
}

list_has() {
  local list="$1"
  local needle="$2"
  local item
  for item in ${list}; do
    if [ "${item}" = "${needle}" ]; then
      return 0
    fi
  done
  return 1
}

array_has() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    if [ "${item}" = "${needle}" ]; then
      return 0
    fi
  done
  return 1
}

compose_file="${COMPOSE_FILE:-}"
if [ -z "${compose_file}" ]; then
  for candidate in docker-compose.yaml docker-compose.yml compose.yaml compose.yml; do
    if [ -f "${candidate}" ]; then
      compose_file="${candidate}"
      break
    fi
  done
fi

# Services that are allowed to publish ports externally.
allowed_raw="${ALLOWED_PUBLISHED_PORT_SERVICES:-koha}"
allowed_normalized="$(normalize_list "${allowed_raw}")"

is_allowed_service() {
  local svc="$1"
  local s
  for s in ${allowed_normalized}; do
    if [ "${svc}" = "${s}" ]; then
      return 0
    fi
  done
  return 1
}

if [ -n "${compose_file}" ]; then
  mapfile -t bindings < <(
    awk '
      { sub(/\r$/, "", $0) }
      /^  [A-Za-z0-9_.-]+:/ {
        svc=$1
        sub(":", "", svc)
        in_ports=0
        next
      }
      /^    ports:/ {
        in_ports=1
        next
      }
      in_ports && /^      - / {
        p=$0
        sub(/^      - /, "", p)
        print svc "|" p
        next
      }
      in_ports && $0 !~ /^      / {
        in_ports=0
      }
    ' "${compose_file}"
  )

  violations=()
  for binding in "${bindings[@]}"; do
    svc="${binding%%|*}"
    port="${binding#*|}"
    if ! is_allowed_service "${svc}"; then
      violations+=("${svc}: ${port}")
    fi
  done

  if [ "${#violations[@]}" -gt 0 ]; then
    echo "Found disallowed published ports in internal services:" >&2
    printf ' - %s\n' "${violations[@]}" >&2
    fail "Policy violation: only [${allowed_normalized}] may define ports."
  fi

  echo "OK: compose published ports policy passed (allowed services: ${allowed_normalized})."
  exit 0
fi

# Current build-repo mode (no compose file in repository).
dockerfile_path="${DOCKERFILE_PATH:-Dockerfile}"
[ -f "${dockerfile_path}" ] || fail "Dockerfile not found: ${dockerfile_path}"

allowed_exposed_raw="${ALLOWED_EXPOSED_PORTS:-2100 6001 8080 8081}"
allowed_exposed_ports="$(normalize_list "${allowed_exposed_raw}")"
required_http_raw="${REQUIRED_HTTP_PORTS:-8080 8081}"
required_http_ports="$(normalize_list "${required_http_raw}")"

mapfile -t exposed_ports < <(
  awk '
    BEGIN { IGNORECASE=1 }
    $1 == "EXPOSE" {
      for (i = 2; i <= NF; i++) {
        token = $i
        sub(/\/.*/, "", token)
        if (token ~ /^[0-9]+$/) {
          print token
        }
      }
    }
  ' "${dockerfile_path}" | sort -u
)

[ "${#exposed_ports[@]}" -gt 0 ] || fail "No EXPOSE ports found in ${dockerfile_path}"

disallowed_exposed=()
for port in "${exposed_ports[@]}"; do
  if ! list_has "${allowed_exposed_ports}" "${port}"; then
    disallowed_exposed+=("${port}")
  fi
done
if [ "${#disallowed_exposed[@]}" -gt 0 ]; then
  fail "Disallowed Dockerfile EXPOSE ports: ${disallowed_exposed[*]} (allowed: ${allowed_exposed_ports})"
fi

missing_required_http=()
for port in ${required_http_ports}; do
  if ! array_has "${port}" "${exposed_ports[@]}"; then
    missing_required_http+=("${port}")
  fi
done
if [ "${#missing_required_http[@]}" -gt 0 ]; then
  fail "Dockerfile missing required HTTP EXPOSE ports: ${missing_required_http[*]}"
fi

ports_conf_path="${PORTS_CONF_PATH:-docker/pinokew/ports.conf}"
if [ -f "${ports_conf_path}" ]; then
  mapfile -t listen_ports < <(
    awk '
      /^[[:space:]]*Listen[[:space:]]+[0-9]+([[:space:]]|$)/ { print $2 }
    ' "${ports_conf_path}" | sort -u
  )

  [ "${#listen_ports[@]}" -gt 0 ] || fail "No Listen ports found in ${ports_conf_path}"

  extra_listen=()
  for port in "${listen_ports[@]}"; do
    if ! list_has "${required_http_ports}" "${port}"; then
      extra_listen+=("${port}")
    fi
  done
  if [ "${#extra_listen[@]}" -gt 0 ]; then
    fail "Disallowed Listen ports in ${ports_conf_path}: ${extra_listen[*]} (required HTTP ports: ${required_http_ports})"
  fi

  missing_listen=()
  for port in ${required_http_ports}; do
    if ! array_has "${port}" "${listen_ports[@]}"; then
      missing_listen+=("${port}")
    fi
  done
  if [ "${#missing_listen[@]}" -gt 0 ]; then
    fail "${ports_conf_path} missing required Listen ports: ${missing_listen[*]}"
  fi
fi

vhost_path="${VHOST_PATH:-files/etc/apache2/sites-available/library.conf}"
if [ -f "${vhost_path}" ]; then
  mapfile -t vhost_ports < <(
    awk '
      /<VirtualHost/ {
        if (match($0, /:[0-9]+>/)) {
          print substr($0, RSTART + 1, RLENGTH - 2)
        }
      }
    ' "${vhost_path}" | sort -u
  )

  [ "${#vhost_ports[@]}" -gt 0 ] || fail "No VirtualHost ports found in ${vhost_path}"

  extra_vhost=()
  for port in "${vhost_ports[@]}"; do
    if ! list_has "${required_http_ports}" "${port}"; then
      extra_vhost+=("${port}")
    fi
  done
  if [ "${#extra_vhost[@]}" -gt 0 ]; then
    fail "Disallowed VirtualHost ports in ${vhost_path}: ${extra_vhost[*]} (required HTTP ports: ${required_http_ports})"
  fi

  missing_vhost=()
  for port in ${required_http_ports}; do
    if ! array_has "${port}" "${vhost_ports[@]}"; then
      missing_vhost+=("${port}")
    fi
  done
  if [ "${#missing_vhost[@]}" -gt 0 ]; then
    fail "${vhost_path} missing required VirtualHost ports: ${missing_vhost[*]}"
  fi
fi

echo "OK: internal ports policy passed (Dockerfile EXPOSE + Apache ports contract)."
