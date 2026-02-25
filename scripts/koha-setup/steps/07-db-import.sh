#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env

if ! koha-mysql "${KOHA_INSTANCE}" -e "SELECT * FROM systempreferences LIMIT 1;" >/dev/null 2>&1; then
  echo "WARNING: Database empty. Importing structure..."
  STRUCT_FILE="$(find /usr/share/koha -name "kohastructure.sql" | head -n 1)"
  if [ -n "${STRUCT_FILE}" ]; then
    sed '/TIME_ZONE/Id' "${STRUCT_FILE}" | koha-mysql "${KOHA_INSTANCE}"
    echo "INFO: Imported structure."
  fi
fi
