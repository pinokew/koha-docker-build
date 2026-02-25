#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env

echo "Setting up directories..."
for d in "/var/log/koha/apache" \
         "/var/log/koha/${KOHA_INSTANCE}" \
         "/var/run/koha/${KOHA_INSTANCE}" \
         "/var/spool/koha/${KOHA_INSTANCE}" \
         "/var/cache/koha/${KOHA_INSTANCE}" \
         "/var/lib/koha/${KOHA_INSTANCE}" \
         "/var/lib/koha/${KOHA_INSTANCE}/plugins"; do
  mkdir -p "${d}" 2>/dev/null || true
done

chown -R "${KOHA_USER}:${KOHA_USER}" /var/log/koha /var/run/koha
chmod -R 755 /var/log/koha /var/run/koha

chown -R "${KOHA_USER}:${KOHA_USER}" /var/spool/koha /var/cache/koha /var/lib/koha
chmod -R g+rwX /var/spool/koha /var/cache/koha /var/lib/koha
