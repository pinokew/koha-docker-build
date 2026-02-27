#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env
require_db_env
source_koha_functions_if_present

echo "Running koha-create logic..."

# Normalize ports.conf with runtime ports before Apache syntax checks.
printf "Listen %s\nListen %s\n" "${KOHA_INTRANET_PORT}" "${KOHA_OPAC_PORT}" > /etc/apache2/ports.conf

if ! apachectl -t; then
  echo "ERROR: apachectl -t failed before koha-create."
  exit 1
fi

ES_PARAMS=()
if [ "${USE_ELASTICSEARCH}" = "true" ]; then
  ES_PARAMS+=(--elasticsearch-server "${ELASTICSEARCH_HOST}")
fi

set +e
koha-create --timezone "${TZ}" --use-db "${KOHA_INSTANCE}" "${ES_PARAMS[@]}" \
  --mb-host "${MB_HOST}" --mb-port "${MB_PORT}" --mb-user "${MB_USER}" --mb-pass "${MB_PASS}"
KOHA_CREATE_RC=$?
set -e

if [ "${KOHA_CREATE_RC}" -ne 0 ]; then
  echo "ERROR: koha-create failed with code ${KOHA_CREATE_RC}"
  exit "${KOHA_CREATE_RC}"
fi

if [ ! -s "${KOHA_CONF}" ]; then
  echo "ERROR: koha-create completed but KOHA config was not created: ${KOHA_CONF}"
  exit 1
fi

install -d -m 755 /etc/koha-envvars
printf "%s\n" "${KOHA_INSTANCE}" > /etc/koha-envvars/INSTANCE_NAME
printf "%s\n" "${KOHA_CONF}" > /etc/koha-envvars/KOHA_CONF
