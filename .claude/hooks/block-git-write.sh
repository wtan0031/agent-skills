#!/usr/bin/env bash
# PreToolUse(Bash) guard — turns the CLAUDE.md "never commit unless asked" rule
# from a suggestion into a hard block. Exit 2 = deny the tool call and feed this
# script's stderr back to Claude as the reason.
#
# Escape hatch: prefix the command with CLAUDE_GIT_OK=1 once the user has
# explicitly authorised the write in this session.

set -uo pipefail

cmd="$(python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    print("")
' 2>/dev/null)"

[[ -z "$cmd" ]] && exit 0

# Explicit per-invocation override.
[[ "$cmd" == *"CLAUDE_GIT_OK=1"* ]] && exit 0

# Strip --dry-run invocations, which write nothing.
[[ "$cmd" == *"--dry-run"* ]] && exit 0

blocked=""
case "$cmd" in
  *"git commit"*)   blocked="git commit" ;;
  *"git push"*)     blocked="git push" ;;
  *"gh pr create"*) blocked="gh pr create" ;;
  *"git tag"*)      blocked="git tag" ;;
esac

[[ -z "$blocked" ]] && exit 0

cat >&2 <<EOF
BLOCKED by .claude/hooks/block-git-write.sh: '$blocked' is not permitted.

This repo requires explicit, in-session user authorisation before any commit,
push, tag, or PR. Prior-session permission does not carry over, and "save",
"finalize" or "ship it" do not count.

Do this instead:
  1. Stop. Ask the user to confirm they want this specific write.
  2. Only after they confirm, re-run the command prefixed with CLAUDE_GIT_OK=1.

Do not attempt to work around this hook.
EOF
exit 2
