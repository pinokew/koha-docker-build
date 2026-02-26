#!/usr/bin/env bash
# Модульний раннер налаштування Koha. Автоматично знаходить пронумеровані кроки.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEPS_DIR="${KOHA_SETUP_STEPS_DIR:-${SCRIPT_DIR}/steps}"
STEP_GLOB="${KOHA_SETUP_STEP_GLOB:-[0-9][0-9]-*.sh}"
FAIL_FAST="${KOHA_SETUP_FAIL_FAST:-false}"
REQUIRED_STEPS="${KOHA_SETUP_REQUIRED_STEPS:-00-env-checks.sh}"
SKIP_STEPS="${KOHA_SETUP_SKIP_STEPS:-}"
ONLY_STEPS="${KOHA_SETUP_ONLY_STEPS:-}"

declare -a FAILED_OPTIONAL_STEPS=()
declare -a FAILED_REQUIRED_STEPS=()

is_in_word_list() {
  local needle="$1"
  local list="$2"
  local item=""

  for item in ${list}; do
    if [ "${item}" = "${needle}" ]; then
      return 0
    fi
  done
  return 1
}

matches_glob_list() {
  local value="$1"
  local glob_list="$2"
  local glob=""

  for glob in ${glob_list}; do
    # shellcheck disable=SC2053
    if [[ "${value}" == ${glob} ]]; then
      return 0
    fi
  done
  return 1
}

step_mode_for() {
  local step_name="$1"
  if is_in_word_list "${step_name}" "${REQUIRED_STEPS}"; then
    echo "required"
  else
    echo "optional"
  fi
}

should_run_step() {
  local step_name="$1"

  if [ -n "${ONLY_STEPS}" ] && ! is_in_word_list "${step_name}" "${ONLY_STEPS}"; then
    return 1
  fi

  if [ -n "${SKIP_STEPS}" ] && matches_glob_list "${step_name}" "${SKIP_STEPS}"; then
    return 1
  fi

  return 0
}

run_step() {
  local mode="$1"
  local step_path="$2"
  local step_name
  step_name="$(basename "${step_path}")"

  echo "[setup] START: ${step_name} (${mode})"

  if [ ! -x "${step_path}" ]; then
    if [ "${mode}" = "required" ]; then
      echo "[setup] FAIL: required step not executable: ${step_name}"
      FAILED_REQUIRED_STEPS+=("${step_name} (missing executable)")
      return 1
    fi
    echo "[setup] WARN: optional step not executable: ${step_name}"
    FAILED_OPTIONAL_STEPS+=("${step_name} (missing executable)")
    return 0
  fi

  "${step_path}"
  local rc=$?

  if [ "${rc}" -eq 0 ]; then
    echo "[setup] OK: ${step_name}"
    return 0
  fi

  if [ "${mode}" = "required" ]; then
    echo "[setup] FAIL: required step '${step_name}' exited with ${rc}"
    FAILED_REQUIRED_STEPS+=("${step_name} (exit ${rc})")
    return 1
  fi

  echo "[setup] WARN: optional step '${step_name}' exited with ${rc}"
  FAILED_OPTIONAL_STEPS+=("${step_name} (exit ${rc})")
  return 0
}

if [ ! -d "${STEPS_DIR}" ]; then
  echo "[setup] FAIL: steps directory does not exist: ${STEPS_DIR}"
  exit 1
fi

mapfile -t STEP_FILES < <(find "${STEPS_DIR}" -maxdepth 1 -type f -name "${STEP_GLOB}" | sort)

if [ "${#STEP_FILES[@]}" -eq 0 ]; then
  echo "[setup] FAIL: no steps found in ${STEPS_DIR} matching ${STEP_GLOB}"
  exit 1
fi

for step_path in "${STEP_FILES[@]}"; do
  step_name="$(basename "${step_path}")"

  if ! should_run_step "${step_name}"; then
    echo "[setup] SKIP: ${step_name}"
    continue
  fi

  mode="$(step_mode_for "${step_name}")"
  if ! run_step "${mode}" "${step_path}"; then
    if [ "${mode}" = "required" ]; then
      echo "[setup] Required step failed, stopping on ${step_name}."
      break
    fi
    if [ "${FAIL_FAST}" = "true" ]; then
      echo "[setup] FAIL_FAST enabled, stopping on ${step_name}."
      break
    fi
  fi
done

if [ "${#FAILED_REQUIRED_STEPS[@]}" -gt 0 ]; then
  echo "[setup] Completed with required step failures:"
  for step in "${FAILED_REQUIRED_STEPS[@]}"; do
    echo "[setup]  - ${step}"
  done
  if [ "${#FAILED_OPTIONAL_STEPS[@]}" -gt 0 ]; then
    echo "[setup] Optional failures:"
    for step in "${FAILED_OPTIONAL_STEPS[@]}"; do
      echo "[setup]  - ${step}"
    done
  fi
  exit 1
fi

if [ "${#FAILED_OPTIONAL_STEPS[@]}" -gt 0 ]; then
  echo "[setup] Completed with warnings. Failed optional steps:"
  for step in "${FAILED_OPTIONAL_STEPS[@]}"; do
    echo "[setup]  - ${step}"
  done
else
  echo "[setup] Completed successfully. All steps finished."
fi

echo "Setup Finished."
exit 0
