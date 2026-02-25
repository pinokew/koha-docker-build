#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env
require_db_env
source_koha_functions_if_present

echo "Running koha-create logic..."

ES_PARAMS=()
if [ "${USE_ELASTICSEARCH}" = "true" ]; then
  ES_PARAMS+=(--elasticsearch-server "${ELASTICSEARCH_HOST}")
fi

set +e
koha-create --timezone "${TZ}" --use-db "${KOHA_INSTANCE}" "${ES_PARAMS[@]}" \
  --mb-host "${MB_HOST}" --mb-port "${MB_PORT}" --mb-user "${MB_USER}" --mb-pass "${MB_PASS}"
KOHA_CREATE_RC=$?
set -e

if [ -f /docker/templates/koha-conf-site.xml.in ]; then
  rm -f "/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml"
  cp /docker/templates/koha-conf-site.xml.in "/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml"
  chown "${KOHA_USER}:${KOHA_USER}" "/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml"
  chmod 640 "/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml"
fi

if [ "${KOHA_CREATE_RC}" -ne 0 ]; then
  echo "WARNING: koha-create failed with code ${KOHA_CREATE_RC}"
  exit "${KOHA_CREATE_RC}"
fi
