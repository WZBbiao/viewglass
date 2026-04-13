#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNS_DIR="${ROOT_DIR}/.claude-runs"
STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="${RUNS_DIR}/${STAMP}"
PROMPT_FILE="${ROOT_DIR}/Docs/ClaudeCode-LookinCLI-Prompt.md"
LEDGER_FILE="${ROOT_DIR}/Docs/lookin-cli-progress.md"
MODEL="${CLAUDE_MODEL:-}"
WORK_BRANCH="${CLAUDE_WORK_BRANCH:-codex/lookin-cli}"
AUTOCOMMIT_SCRIPT="${ROOT_DIR}/scripts/claude-lookin-autocommit.sh"

mkdir -p "${RUN_DIR}"

if ! command -v claude >/dev/null 2>&1; then
  echo "Missing 'claude' CLI in PATH." >&2
  exit 1
fi

if ! git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Repository is not a git work tree: ${ROOT_DIR}" >&2
  exit 1
fi

if [[ ! -f "${PROMPT_FILE}" ]]; then
  echo "Prompt file not found: ${PROMPT_FILE}" >&2
  exit 1
fi

if [[ ! -f "${LEDGER_FILE}" ]]; then
  cat > "${LEDGER_FILE}" <<'EOF'
# Lookin CLI Progress

## Current Milestone

- Bootstrap

## Completed Changes

- Initialized progress ledger

## Open Risks

- None recorded yet

## Commands And Tests Run

- None yet

## Latest Checkpoint Commit

- None yet

## Next Step

- Read the blueprint and start extraction work
EOF
fi

cat <<EOF
Run directory: ${RUN_DIR}
Repository: ${ROOT_DIR}
Prompt: ${PROMPT_FILE}
Ledger: ${LEDGER_FILE}
Work branch: ${WORK_BRANCH}
EOF

CURRENT_BRANCH="$(git -C "${ROOT_DIR}" branch --show-current)"
if [[ "${CURRENT_BRANCH}" != "${WORK_BRANCH}" ]]; then
  if git -C "${ROOT_DIR}" show-ref --verify --quiet "refs/heads/${WORK_BRANCH}"; then
    git -C "${ROOT_DIR}" checkout "${WORK_BRANCH}"
  else
    git -C "${ROOT_DIR}" checkout -b "${WORK_BRANCH}"
  fi
fi

ARGS=(
  --dangerously-skip-permissions
  --cwd "${ROOT_DIR}"
)

if [[ -n "${MODEL}" ]]; then
  ARGS+=(--model "${MODEL}")
fi

set +e
claude "${ARGS[@]}" < "${PROMPT_FILE}" \
  2>&1 | tee "${RUN_DIR}/claude.log"
STATUS=${PIPESTATUS[0]}
set -e

echo "${STATUS}" > "${RUN_DIR}/exit_code.txt"
echo "Claude exit code: ${STATUS}"

if [[ -x "${AUTOCOMMIT_SCRIPT}" ]]; then
  "${AUTOCOMMIT_SCRIPT}" "post-run checkpoint ${STAMP}" || true
fi

exit "${STATUS}"
