#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MESSAGE_SUFFIX="${1:-checkpoint}"
BRANCH="${CLAUDE_WORK_BRANCH:-codex/lookin-cli}"
LEDGER_FILE="${ROOT_DIR}/Docs/lookin-cli-progress.md"

if ! git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: ${ROOT_DIR}" >&2
  exit 1
fi

CURRENT_BRANCH="$(git -C "${ROOT_DIR}" branch --show-current)"
if [[ "${CURRENT_BRANCH}" != "${BRANCH}" ]]; then
  echo "Skipping autocommit because current branch is ${CURRENT_BRANCH}, expected ${BRANCH}."
  exit 0
fi

if [[ -z "$(git -C "${ROOT_DIR}" status --porcelain)" ]]; then
  echo "No changes to commit."
  exit 0
fi

git -C "${ROOT_DIR}" add -A
git -C "${ROOT_DIR}" commit -m "lookin-cli: ${MESSAGE_SUFFIX}"

COMMIT_HASH="$(git -C "${ROOT_DIR}" rev-parse --short HEAD)"
if [[ -f "${LEDGER_FILE}" ]]; then
  python3 - <<'PY' "${LEDGER_FILE}" "${COMMIT_HASH}"
from pathlib import Path
import sys

ledger = Path(sys.argv[1])
commit_hash = sys.argv[2]
text = ledger.read_text()
marker = "## Latest Checkpoint Commit"
replacement = f"{marker}\n\n- `{commit_hash}`"
if marker in text:
    head, _, tail = text.partition(marker)
    if "\n## " in tail:
        _, rest = tail.split("\n## ", 1)
        text = head + replacement + "\n## " + rest
    else:
        text = head + replacement + "\n"
else:
    text += f"\n{replacement}\n"
ledger.write_text(text)
PY
  git -C "${ROOT_DIR}" add "${LEDGER_FILE}"
  if [[ -n "$(git -C "${ROOT_DIR}" status --porcelain)" ]]; then
    git -C "${ROOT_DIR}" commit --amend --no-edit >/dev/null
  fi
fi

echo "Created checkpoint commit ${COMMIT_HASH}"
