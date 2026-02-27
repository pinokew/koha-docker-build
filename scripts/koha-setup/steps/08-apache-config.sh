#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env

# Always render ports.conf with real newlines and env ports.
printf "Listen %s\nListen %s\n" "${KOHA_INTRANET_PORT}" "${KOHA_OPAC_PORT}" > /etc/apache2/ports.conf

sed -i "s/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER=${KOHA_USER}/" /etc/apache2/envvars
sed -i "s/^export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=${KOHA_USER}/" /etc/apache2/envvars

# Remove mpm_itk directives from all instance-related vhost files.
for site in /etc/apache2/sites-available/"${KOHA_INSTANCE}"*.conf; do
  [ -f "${site}" ] || continue
  sed -i '/^[[:space:]]*AssignUserID[[:space:]].*$/d' "${site}" || true
done

if [ -f "/etc/apache2/sites-available/${KOHA_INSTANCE}.conf" ]; then
  APACHE_SITE="/etc/apache2/sites-available/${KOHA_INSTANCE}.conf"

  if [ -n "${KOHA_OPAC_SERVERNAME}" ]; then
    OPAC_HOST="${KOHA_OPAC_SERVERNAME}"
  else
    OPAC_HOST="${KOHA_OPAC_PREFIX}${KOHA_INSTANCE}${KOHA_OPAC_SUFFIX}.${KOHA_DOMAIN}"
  fi

  if [ -n "${KOHA_INTRANET_SERVERNAME}" ]; then
    INTRANET_HOST="${KOHA_INTRANET_SERVERNAME}"
  else
    INTRANET_HOST="${KOHA_INTRANET_PREFIX}${KOHA_INSTANCE}${KOHA_INTRANET_SUFFIX}.${KOHA_DOMAIN}"
  fi

  awk \
    -v opac_port="${KOHA_OPAC_PORT}" \
    -v intranet_port="${KOHA_INTRANET_PORT}" \
    -v opac_host="${OPAC_HOST}" \
    -v intranet_host="${INTRANET_HOST}" \
    -v conf="${KOHA_CONF}" \
    '
    BEGIN { vhost=0; }
    /^[[:space:]]*AssignUserID[[:space:]].*$/ { next; }
    /^[[:space:]]*<VirtualHost[[:space:]]+\*:[0-9]+>[[:space:]]*$/ {
      vhost++;
      if (vhost == 1) {
        $0 = "<VirtualHost *:" opac_port ">";
      } else if (vhost == 2) {
        $0 = "<VirtualHost *:" intranet_port ">";
      }
      print;
      next;
    }
    /^[[:space:]]*ServerName[[:space:]].*$/ {
      if (vhost == 1) {
        $0 = "   ServerName " opac_host;
      } else if (vhost == 2) {
        $0 = "   ServerName " intranet_host;
      }
      print;
      next;
    }
    /^[[:space:]]*SetEnv[[:space:]]+KOHA_CONF[[:space:]].*$/ {
      if (vhost == 1 || vhost == 2) {
        $0 = "   SetEnv KOHA_CONF \"" conf "\"";
      }
      print;
      next;
    }
    { print; }
  ' "${APACHE_SITE}" > "${APACHE_SITE}.tmp" && mv "${APACHE_SITE}.tmp" "${APACHE_SITE}"

  ln -sf "../sites-available/${KOHA_INSTANCE}.conf" "/etc/apache2/sites-enabled/${KOHA_INSTANCE}.conf"
fi
