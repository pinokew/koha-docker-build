#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env

echo "KOHA_LANGS at startup: '${KOHA_LANGS:-}'"

EXISTING_LANGS="$(koha-translate -l 2>/dev/null || true)"
for lang in ${EXISTING_LANGS}; do
  if [ -z "${KOHA_LANGS:-}" ] || ! echo "${KOHA_LANGS}" | grep -q -w "${lang}"; then
    echo "Removing language ${lang}"
    koha-translate -r "${lang}" || echo "WARNING: Failed to remove language ${lang}"
  fi
done

if [ -n "${KOHA_LANGS:-}" ]; then
  echo "Installing languages (KOHA_LANGS=${KOHA_LANGS})"
  EXISTING_LANGS="$(koha-translate -l 2>/dev/null || true)"

  for lang in ${KOHA_LANGS}; do
    if ! echo "${EXISTING_LANGS}" | grep -q -w "${lang}"; then
      echo "Installing language ${lang}..."
      koha-translate -i "${lang}" || echo "WARNING: Failed to install language ${lang}"
    else
      echo "Language ${lang} already present"
    fi
  done

  LANGS_CSV="$(echo "${KOHA_LANGS}" | tr ' ' ',')"
  if koha-mysql "${KOHA_INSTANCE}" -e "SHOW TABLES LIKE 'systempreferences';" | grep -q systempreferences; then
    echo "Updating systempreferences: language, opaclanguages -> ${LANGS_CSV}"
    koha-mysql "${KOHA_INSTANCE}" -e \
      "UPDATE systempreferences SET value='${LANGS_CSV}' WHERE variable IN ('language', 'opaclanguages');" \
      || echo "WARNING: Failed to update systempreferences language values"
  fi
fi
