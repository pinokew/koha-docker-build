#!/usr/bin/env bash
# Script Purpose: Validate secret hygiene for current build repo.
# Usage: Run on host: ./scripts/check-secrets-hygiene.sh (used in CI pre-checks).
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

normalize_path() {
  local path="${1:-}"
  if [ "${path}" = "." ]; then
    echo "."
  else
    echo "${path%/}"
  fi
}

dockerignore_has_env_rule() {
  local file="$1"
  awk '
    {
      line = $0
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line == ".env" || line == "/.env" || line == "**/.env" || line == "*/.env" || line == "*.env" || line == "**/*.env" || line == ".env*") {
        found = 1
      }
    }
    END { exit(found ? 0 : 1) }
  ' "${file}"
}

echo "[1/4] Checking git repository state..."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Current directory is not a git repository."

echo "[2/4] Checking that .env-like files are not tracked..."
mapfile -t tracked_env_files < <(
  git ls-files | awk '
    /(^|\/)\.env$/ { print; next }
    /(^|\/)\.env\.[^/]+$/ && $0 !~ /(^|\/)\.env\.example$/ { print }
  '
)
if [ "${#tracked_env_files[@]}" -gt 0 ]; then
  printf 'Tracked .env-like files found:\n' >&2
  printf ' - %s\n' "${tracked_env_files[@]}" >&2
  fail "Secrets policy violation: .env files must not be tracked (except .env.example)."
fi

mapfile -t tracked_key_files < <(
  git ls-files | awk '
    /(^|\/)(id_rsa|id_dsa|id_ecdsa|id_ed25519)(\.pub)?$/ { print; next }
    /\.(pem|key|p12|pfx)$/ { print }
  '
)
if [ "${#tracked_key_files[@]}" -gt 0 ]; then
  printf 'Tracked key-like files found:\n' >&2
  printf ' - %s\n' "${tracked_key_files[@]}" >&2
  fail "Secrets policy violation: key/certificate material should not be committed."
fi

echo "[3/4] Collecting Docker build contexts from workflow..."
contexts=(.)
workflow_path=".github/workflows/build-and-push.yml"
if [ -f "${workflow_path}" ]; then
  while IFS= read -r ctx; do
    [ -n "${ctx}" ] || continue
    case "${ctx}" in
      *\$\{\{* ) continue ;;
    esac
    contexts+=("$(normalize_path "${ctx}")")
  done < <(
    awk '
      /^[[:space:]]*context:[[:space:]]*/ {
        line = $0
        sub(/^[[:space:]]*context:[[:space:]]*/, "", line)
        sub(/[[:space:]]+#.*/, "", line)
        gsub(/^["\047]|["\047]$/, "", line)
        if (line != "") print line
      }
    ' "${workflow_path}" | sort -u
  )
fi

declare -A seen_contexts=()
unique_contexts=()
for ctx in "${contexts[@]}"; do
  ctx="$(normalize_path "${ctx}")"
  [ -d "${ctx}" ] || continue
  if [ -z "${seen_contexts[${ctx}]+x}" ]; then
    seen_contexts["${ctx}"]=1
    unique_contexts+=("${ctx}")
  fi
done

echo "[4/4] Checking .dockerignore rules for Docker build contexts..."
for ctx in "${unique_contexts[@]}"; do
  if [ "${ctx}" = "." ]; then
    dockerignore_path=".dockerignore"
  else
    dockerignore_path="${ctx}/.dockerignore"
  fi

  [ -f "${dockerignore_path}" ] || fail "Missing ${dockerignore_path} for Docker context '${ctx}'."
  if ! dockerignore_has_env_rule "${dockerignore_path}"; then
    fail "${dockerignore_path} does not ignore .env files."
  fi
done

if [ ! -f ".gitignore" ]; then
  fail "Missing .gitignore in repository root."
fi
if ! grep -Eq '^[[:space:]]*\.env([[:space:]]*|$)' .gitignore; then
  fail ".gitignore does not ignore .env."
fi

echo "OK: secrets hygiene checks passed."
