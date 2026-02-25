#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env
require_db_env

echo "Deploying configs from /docker/templates/..."

rm -f /etc/koha/koha-sites.conf
cp /docker/templates/koha-sites.conf /etc/koha/koha-sites.conf

rm -f /etc/mysql/koha-common.cnf
cp /docker/templates/koha-common.cnf /etc/mysql/koha-common.cnf
chmod 640 /etc/mysql/koha-common.cnf

rm -f /etc/koha/SIPconfig.xml
cp /docker/templates/SIPconfig.xml /etc/koha/SIPconfig.xml

mkdir -p "/etc/koha/sites/${KOHA_INSTANCE}"
rm -f "/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml"
cp /docker/templates/koha-conf-site.xml.in "/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml"

chown -R "${KOHA_USER}:${KOHA_USER}" "/etc/koha/sites/${KOHA_INSTANCE}"
chmod 750 "/etc/koha/sites/${KOHA_INSTANCE}"
chmod 640 "/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml"

rm -f /etc/koha/koha-conf.xml
ln -sf "/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml" /etc/koha/koha-conf.xml

rm -f /etc/koha/passwd
echo -n "${KOHA_INSTANCE}:${MYSQL_USER}:${MYSQL_PASSWORD}:${DB_NAME}:${MYSQL_SERVER}" > /etc/koha/passwd
chmod 640 /etc/koha/passwd
chown root:"${KOHA_USER}" /etc/koha/passwd
