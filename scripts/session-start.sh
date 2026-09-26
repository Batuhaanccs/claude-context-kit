#!/usr/bin/env bash
# context-kit SessionStart hook: injects docs/STATE.md into Claude's context.
# Contract: never fails the session. Any problem -> print nothing and exit 0.
# Only files created by context-kit are injected: STATE.md must carry the "context-kit" marker
# in its first lines, so unrelated docs/STATE.md files in other projects are never touched.

set -u

STATE_MAX_LINES=150 # hard cap on injected lines (protects the context window)
STATE_BUDGET=40     # soft budget; above this we suggest doc-hygiene

DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
command -v cygpath >/dev/null 2>&1 && DIR=$(cygpath -u "$DIR" 2>/dev/null || printf '%s' "$DIR")
cd "$DIR" 2>/dev/null || exit 0
STATE="docs/STATE.md"
[ -f "$STATE" ] && [ ! -L "$STATE" ] || exit 0
head -n 5 "$STATE" | grep -q 'context-kit' || exit 0

# Read hook input (JSON on stdin) and extract "source" without depending on jq.
INPUT=""
[ -t 0 ] || INPUT=$(cat 2>/dev/null)
SOURCE=$(printf '%s' "$INPUT" | tr -d '\r\n' | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p')
[ -n "$SOURCE" ] || SOURCE="startup"

LINES=$(awk 'END { print NR }' "$STATE")
NOW=$(date +%s)
MTIME=$(stat -c %Y "$STATE" 2>/dev/null || stat -f %m "$STATE" 2>/dev/null || echo "$NOW")
AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
[ "$AGE_DAYS" -lt 0 ] && AGE_DAYS=0

case "$SOURCE" in
  compact)
    HOW="Context was just compacted. The conversation summary is NEWER than this file: where they disagree, trust the summary. Continue the current task without stopping for confirmation; update STATE.md at the next handoff." ;;
  resume)
    HOW="This is a resumed conversation. Its history is newer than this file." ;;
  *)
    HOW="This is a handoff note from an earlier session: a starting hypothesis, not ground truth; it may be outdated if work happened without a handoff. If the user's request concerns an item below, check it against the actual files and confirm your understanding in at most 4 lines before acting. If the request is unrelated, do not summarize this note; just help." ;;
esac

echo "=== context-kit: docs/STATE.md (handoff note, auto-injected; $LINES lines, last modified $AGE_DAYS day(s) ago) ==="
echo "$HOW"
echo "---"
head -n "$STATE_MAX_LINES" "$STATE"
[ -n "$(tail -c 1 "$STATE")" ] && echo
if [ "$LINES" -gt "$STATE_MAX_LINES" ]; then
  echo "--- [truncated at $STATE_MAX_LINES of $LINES lines: read docs/STATE.md for the rest, then suggest doc-hygiene] ---"
elif [ "$LINES" -gt "$STATE_BUDGET" ]; then
  echo "--- [STATE.md is $LINES lines, budget $STATE_BUDGET: suggest doc-hygiene at a natural pause] ---"
fi
echo "=== end of STATE.md. Save state with the handoff skill (\"handoff\" / \"devret\") before ending. ==="
exit 0
