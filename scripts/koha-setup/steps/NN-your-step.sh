#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/koha-setup-common.sh"

init_koha_setup_env

# Шаблон нового кроку setup-пайплайну.
# 1) Скопіюй файл.
# 2) Перейменуй NN на номер, наприклад 11-your-step.sh.
# 3) Додай робочу логіку нижче.

echo "Template step: replace with your own logic."
