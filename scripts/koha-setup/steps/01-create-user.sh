#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env

if ! id -u "${KOHA_USER}" >/dev/null 2>&1; then
  echo "Creating system user '${KOHA_USER}' (UID 1000)..."
  addgroup --gid 1000 "${KOHA_USER}" || true
  adduser --no-create-home --disabled-password --gecos "" --uid 1000 --ingroup "${KOHA_USER}" "${KOHA_USER}" || echo "User creation warning"
  mkdir -p "/home/${KOHA_USER}"
  chown "${KOHA_USER}:${KOHA_USER}" "/home/${KOHA_USER}"
fi
