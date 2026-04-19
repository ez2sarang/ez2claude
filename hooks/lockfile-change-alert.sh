#!/bin/bash
# lockfile-change-alert.sh
# PostToolUse hook: alerts when lock files have been modified.
# Defense strategy: review new transitive dependencies after any install.
#
# Only checks after Bash commands that might modify lock files.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Only check after install-like commands
if ! echo "$COMMAND" | grep -qEi '(npm|yarn|pnpm|bun|pip|uv|poetry)\s+(install|add|ci|sync|update|upgrade|i)\b'; then
  exit 0
fi

# Check if any lock files were modified (git status)
LOCK_CHANGES=$(git diff --name-only 2>/dev/null | grep -Ei '(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb|uv\.lock|poetry\.lock|Pipfile\.lock|requirements\.txt)' 2>/dev/null)

if [ -n "$LOCK_CHANGES" ]; then
  echo "[LOCKFILE-ALERT] Lock file(s) changed after install:" >&2
  echo "$LOCK_CHANGES" | while read f; do
    echo "  - $f" >&2
  done
  echo "  ACTION: Review new/changed dependencies before committing." >&2
  echo "  Run 'git diff <lockfile>' to see what was added." >&2
fi

exit 0
