#!/usr/bin/env bash
# context-kit SessionStart hook.
# Injects docs/STATE.md into Claude's context plus a staleness check against git.
# Contract: never fails the session. Any problem -> print nothing (or what we have) and exit 0.
# Projects without docs/STATE.md are untouched: the hook exits silently.

set -u

STATE_MAX_LINES=150 # hard cap on injected lines (protects the context window)
STATE_BUDGET=40     # soft budget; above this we suggest doc-hygiene
STALE_DAYS=14       # "old" threshold when commits cannot tell us anything

DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
command -v cygpath >/dev/null 2>&1 && DIR=$(cygpath -u "$DIR" 2>/dev/null || printf '%s' "$DIR")
cd "$DIR" 2>/dev/null || exit 0
STATE="docs/STATE.md"
[ -f "$STATE" ] || exit 0

# Read hook input (JSON on stdin) and extract "source" without depending on jq.
INPUT=""
[ -t 0 ] || INPUT=$(cat 2>/dev/null)
SOURCE=$(printf '%s' "$INPUT" | tr -d '\r\n' | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p')
[ -n "$SOURCE" ] || SOURCE="startup"

# Run git with a timeout when available, so a huge or broken repo can never hang session start.
if command -v timeout >/dev/null 2>&1; then G() { timeout 5 git "$@" 2>/dev/null; }; else G() { git "$@" 2>/dev/null; }; fi

LINES=$(wc -l < "$STATE" | tr -d ' ')
NOW=$(date +%s)
MTIME=$(stat -c %Y "$STATE" 2>/dev/null || date -r "$STATE" +%s 2>/dev/null || echo "$NOW")
AGE_DAYS=$(( (NOW - MTIME) / 86400 ))

# ---- Staleness: what happened in git after STATE.md was last updated? ----
STALE_NOTE=""
if [ "$(G rev-parse --is-inside-work-tree)" = "true" ]; then
  HEAD_TIME=$(G log -1 --format=%ct)
  STATE_DIRTY=$(G status --porcelain -- "$STATE")
  LAST_STATE_COMMIT=$(G log -1 --format=%H -- "$STATE")
  SINCE=""
  if [ -n "$STATE_DIRTY" ] || [ -z "$LAST_STATE_COMMIT" ]; then
    # Uncommitted or untracked STATE: compare by time. Commits newer than the file's mtime are "after".
    SINCE=$(G log -50 --format='%ct %h %s' | awk -v t="$MTIME" '$1 > t { $1=""; print substr($0,2) }')
  else
    SINCE=$(G log -50 --format='%h %s' "$LAST_STATE_COMMIT..HEAD")
  fi
  N_SINCE=0
  [ -n "$SINCE" ] && N_SINCE=$(printf '%s\n' "$SINCE" | wc -l | tr -d ' ')
  N_DIRTY=$(G status --porcelain --untracked-files=no | grep -vc ' docs/' )
  if [ "$N_SINCE" -gt 0 ]; then
    STALE_NOTE="WARNING: $N_SINCE commit(s) since STATE.md was last updated; it may be stale. Newest first:"$'\n'"$(printf '%s\n' "$SINCE" | head -5 | sed 's/^/  /')"
    [ "$N_SINCE" -gt 5 ] && STALE_NOTE="$STALE_NOTE"$'\n'"  ..."
  fi
  if [ "${N_DIRTY:-0}" -gt 0 ]; then
    [ -n "$STALE_NOTE" ] && STALE_NOTE="$STALE_NOTE"$'\n'
    STALE_NOTE="${STALE_NOTE}Working tree: $N_DIRTY uncommitted change(s) outside docs/ (run git status before trusting STATE)."
  fi
  [ -z "$STALE_NOTE" ] && [ -n "$HEAD_TIME" ] && STALE_NOTE="STATE.md is up to date with git (no commits since its last update)."
elif [ "$AGE_DAYS" -ge "$STALE_DAYS" ]; then
  STALE_NOTE="WARNING: STATE.md was last modified $AGE_DAYS days ago (no git to compare); verify before relying on it."
fi

# ---- How to use it, depending on why the session started ----
case "$SOURCE" in
  compact)
    HOW="Context was just compacted. The conversation summary is NEWER than this file: where they disagree, trust the summary. Continue the current task without stopping for confirmation; update STATE.md at the next handoff." ;;
  resume)
    HOW="This is a resumed conversation. Its history is newer than this file unless the warnings above say otherwise." ;;
  *)
    HOW="This is a handoff note from an earlier session: a starting hypothesis, not ground truth. If the user's request concerns an item below, confirm your understanding in at most 3 lines before acting and check it against the code/git. If the request is unrelated, do not summarize this note; just help." ;;
esac

echo "=== context-kit: docs/STATE.md (handoff note, auto-injected; $LINES lines, modified $AGE_DAYS day(s) ago) ==="
[ -n "$STALE_NOTE" ] && printf '%s\n' "$STALE_NOTE"
echo "$HOW"
echo "---"
head -n "$STATE_MAX_LINES" "$STATE"
if [ "$LINES" -gt "$STATE_MAX_LINES" ]; then
  echo "--- [truncated at $STATE_MAX_LINES of $LINES lines: read docs/STATE.md for the rest, then suggest doc-hygiene] ---"
elif [ "$LINES" -gt "$STATE_BUDGET" ]; then
  echo "--- [STATE.md is $LINES lines, budget $STATE_BUDGET: suggest doc-hygiene at a natural pause] ---"
fi
echo "=== end of STATE.md. Save state with the handoff skill (\"handoff\" / \"devret\") before ending. ==="
exit 0
