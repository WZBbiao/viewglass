#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="${ROOT_DIR}/scripts/claude-lookin-harness.sh"
RUNS_DIR="${ROOT_DIR}/.claude-runs"
SLEEP_SECONDS="${CLAUDE_WATCHDOG_SLEEP:-15}"
MAX_ROUNDS="${CLAUDE_WATCHDOG_MAX_ROUNDS:-0}"
AUTOCOMMIT_SCRIPT="${ROOT_DIR}/scripts/claude-lookin-autocommit.sh"
ROUND=0

mkdir -p "${RUNS_DIR}"

if [[ ! -x "${HARNESS}" ]]; then
  echo "Harness is not executable: ${HARNESS}" >&2
  exit 1
fi

while true; do
  ROUND=$((ROUND + 1))
  echo "=== Claude watchdog round ${ROUND} ==="

  set +e
  "${HARNESS}"
  STATUS=$?
  set -e

  echo "Round ${ROUND} exit code: ${STATUS}"

  if [[ -x "${AUTOCOMMIT_SCRIPT}" ]]; then
    "${AUTOCOMMIT_SCRIPT}" "watchdog checkpoint round ${ROUND}" || true
  fi

  if [[ "${STATUS}" -eq 0 ]]; then
    echo "Claude exited cleanly. Stopping watchdog."
    exit 0
  fi

  if [[ "${MAX_ROUNDS}" -gt 0 && "${ROUND}" -ge "${MAX_ROUNDS}" ]]; then
    echo "Reached MAX_ROUNDS=${MAX_ROUNDS}. Stopping watchdog."
    exit "${STATUS}"
  fi

  echo "Sleeping ${SLEEP_SECONDS}s before restart."
  sleep "${SLEEP_SECONDS}"
done
