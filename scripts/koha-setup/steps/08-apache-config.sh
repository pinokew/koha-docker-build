#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env

sed -i "s/^export APACHE_RUN_USER=.*/export APACHE_RUN_USER=${KOHA_USER}/" /etc/apache2/envvars
sed -i "s/^export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=${KOHA_USER}/" /etc/apache2/envvars

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

  sed -i '/^[[:space:]]*AssignUserID[[:space:]].*$/d' "${APACHE_SITE}" || true
  sed -i "0,/^[[:space:]]*ServerName[[:space:]].*$/s//   ServerName ${OPAC_HOST}/" "${APACHE_SITE}" || true
  sed -i "0,/^[[:space:]]*SetEnv[[:space:]]\\+KOHA_CONF[[:space:]].*$/s//   SetEnv KOHA_CONF \"${KOHA_CONF}\"/" "${APACHE_SITE}" || true
  sed -i "0,/^[[:space:]]*<VirtualHost[[:space:]]\\+\\*:.*>$/s//<VirtualHost *:${KOHA_OPAC_PORT}>/" "${APACHE_SITE}" || true

  # Apply intranet mappings on the second vhost block.
  awk -v inport="${KOHA_INTRANET_PORT}" -v inhost="${INTRANET_HOST}" -v conf="${KOHA_CONF}" '
    BEGIN { vhost=0; sname=0; setenv=0; }
    /^[[:space:]]*<VirtualHost[[:space:]]+\*:.*>$/ {
      vhost++;
      if (vhost == 2) {
        sub(/<VirtualHost[[:space:]]+\*:[0-9]+>/, "<VirtualHost *:" inport ">");
      }
    }
    /^[[:space:]]*ServerName[[:space:]].*$/ {
      sname++;
      if (sname == 2) {
        $0 = "   ServerName " inhost;
      }
    }
    /^[[:space:]]*SetEnv[[:space:]]+KOHA_CONF[[:space:]].*$/ {
      setenv++;
      if (setenv == 2) {
        $0 = "   SetEnv KOHA_CONF \"" conf "\"";
      }
    }
    { print }
  ' "${APACHE_SITE}" > "${APACHE_SITE}.tmp" && mv "${APACHE_SITE}.tmp" "${APACHE_SITE}"

  ln -sf "../sites-available/${KOHA_INSTANCE}.conf" "/etc/apache2/sites-enabled/${KOHA_INSTANCE}.conf"
fi
