#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env

a2enmod proxy proxy_http headers rewrite cgi || true
a2dismod mpm_itk || true
echo "ServerName localhost" > /etc/apache2/conf-available/fqdn.conf
a2enconf fqdn || true

if [ -f /etc/koha/plack.psgi ]; then
  sed -i "s|__KOHA_CONF_DIR__|/etc/koha|g" /etc/koha/plack.psgi
  sed -i "s|__TEMPLATE_CACHE_DIR__|/var/cache/koha/${KOHA_INSTANCE}/plack-tmpl|g" /etc/koha/plack.psgi
fi

rm -f "/var/run/koha/${KOHA_INSTANCE}/plack.pid"
rm -f "/var/run/koha/${KOHA_INSTANCE}/plack.sock"

echo "Starting koha-plack..."
koha-plack --enable "${KOHA_INSTANCE}" || true
koha-plack --start "${KOHA_INSTANCE}" || true

koha-worker --start "${KOHA_INSTANCE}" || true
koha-worker --start --queue long_tasks "${KOHA_INSTANCE}" || true

if [ "${USE_ELASTICSEARCH}" = "true" ]; then
  if koha-mysql "${KOHA_INSTANCE}" -e "SHOW TABLES LIKE 'systempreferences';" | grep -q systempreferences; then
    /usr/sbin/koha-es-indexer --start "${KOHA_INSTANCE}" || true
  fi
fi
