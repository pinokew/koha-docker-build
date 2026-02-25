#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/etc/s6-overlay/scripts/lib/koha-setup-common.sh
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env

echo "Generating log4perl.conf..."
rm -f /etc/koha/log4perl.conf
cat >/etc/koha/log4perl.conf <<EOF
log4perl.rootLogger = INFO, LOGFILE
log4perl.appender.LOGFILE = Log::Log4perl::Appender::File
log4perl.appender.LOGFILE.filename = /var/log/koha/${KOHA_INSTANCE}/koha.log
log4perl.appender.LOGFILE.mode = append
log4perl.appender.LOGFILE.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.LOGFILE.layout.ConversionPattern = %d [%p] %m%n
EOF
chown root:root /etc/koha/log4perl.conf
chmod 644 /etc/koha/log4perl.conf
