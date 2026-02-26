#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env
require_db_env

: "${DB_ROOT_PASS:=password}"

echo "[configs] Режим public-image: зовнішні template override вимкнено."

for required_file in \
  /etc/koha/koha-sites.conf \
  /etc/koha/SIPconfig.xml \
  /etc/koha/koha-conf-site.xml.in; do
  if [ ! -f "${required_file}" ]; then
    echo "ERROR: Обов'язковий шаблон Koha не знайдено: ${required_file}"
    exit 1
  fi
done

# Генеруємо koha-common.cnf тільки з env змінних контейнера
cat >/etc/mysql/koha-common.cnf <<CFG
[client]
host     = ${MYSQL_SERVER}
user     = root
password = ${DB_ROOT_PASS}
CFG
chmod 640 /etc/mysql/koha-common.cnf
echo "[configs] Згенеровано /etc/mysql/koha-common.cnf з env."

# passwd для koha-утиліт
rm -f /etc/koha/passwd
echo -n "${KOHA_INSTANCE}:${MYSQL_USER}:${MYSQL_PASSWORD}:${DB_NAME}:${MYSQL_SERVER}" > /etc/koha/passwd
chmod 640 /etc/koha/passwd
chown root:"${KOHA_USER}" /etc/koha/passwd

echo "[configs] Деплой конфігів завершено (public clean mode)."
