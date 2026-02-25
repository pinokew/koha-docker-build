#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env
require_db_env

echo "Environment checks passed for instance '${KOHA_INSTANCE}'."
