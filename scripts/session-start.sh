#!/usr/bin/env bash
# context-kit SessionStart hook.
# Injects docs/STATE.md into Claude's context plus a staleness check against git.
# Contract: never fails the session. Any problem -> print nothing (or what we have) and exit 0.
# Only files created by context-kit are injected: STATE.md must carry the "context-kit" marker
# in its first lines, so unrelated docs/STATE.md files in other repos are never touched.

set -u

STATE_MAX_LINES=150 # hard cap on injected lines (protects the context window)
STATE_BUDGET=40     # soft budget; above this we suggest doc-hygiene
STALE_DAYS=14       # "old" threshold when there is no git to compare with
GIT_BUDGET=6        # seconds; git checks stop after this so the hook never times out

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

# git wrapper: per-call timeout when available, overall time budget, and config that could corrupt
# parsed output (signatures, quoted paths) switched off. --no-optional-locks: never contend for index.lock.
TO=""
if command -v timeout >/dev/null 2>&1; then TO="timeout 3"; elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout 3"; fi
G() {
  [ "$SECONDS" -lt "$GIT_BUDGET" ] || return 1
  $TO git --no-optional-locks -c log.showSignature=false -c core.quotepath=false "$@" 2>/dev/null
}
# Pathspec for "project changes": this directory (works when the project is a subfolder of a repo), minus docs/.
PS=(-- . ':(exclude)docs')

LINES=$(awk 'END { print NR }' "$STATE")
NOW=$(date +%s)
MTIME=$(stat -c %Y "$STATE" 2>/dev/null || stat -f %m "$STATE" 2>/dev/null || echo "$NOW")
AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
[ "$AGE_DAYS" -lt 0 ] && AGE_DAYS=0

# ---- Staleness: what happened in git after STATE.md was last updated? ----
NOTE=""
add_note() { if [ -n "$NOTE" ]; then NOTE="$NOTE"$'\n'"$1"; else NOTE="$1"; fi; }
list() { printf '%s\n' "$1" | head -5 | sed 's/^/  /'; }

if [ "$(G rev-parse --is-inside-work-tree)" = "true" ]; then
  LAST_STATE_COMMIT=$(G log -1 --format=%H -- "$STATE")
  STATE_DIRTY=$(G status --porcelain -- "$STATE")
  SINCE=""; N_SINCE=0
  if [ -n "$LAST_STATE_COMMIT" ]; then
    SINCE=$(G log -50 --format='%h %s' "$LAST_STATE_COMMIT..HEAD" "${PS[@]}")
  else
    # STATE never committed: fall back to time. Project commits newer than the file's mtime are "after".
    SINCE=$(G log -50 --format='%ct %h %s' "${PS[@]}" | awk -v t="$MTIME" '$1 > t { $1=""; print substr($0,2) }')
  fi
  [ -n "$SINCE" ] && N_SINCE=$(printf '%s\n' "$SINCE" | awk 'END { print NR }')

  if [ "$N_SINCE" -gt 0 ] && [ -n "$STATE_DIRTY" ] && [ -n "$LAST_STATE_COMMIT" ]; then
    add_note "NOTE: STATE.md has uncommitted edits; $N_SINCE project commit(s) since its last committed version. Items not touched by those edits may be stale:"
    add_note "$(list "$SINCE")"
  elif [ "$N_SINCE" -gt 0 ]; then
    add_note "WARNING: $N_SINCE project commit(s) since STATE.md was last updated; it may be stale. Newest first:"
    add_note "$(list "$SINCE")"
  fi
  [ "$N_SINCE" -gt 5 ] && add_note "  ..."

  CHANGES=$(G status --porcelain "${PS[@]}")
  if [ -n "$CHANGES" ]; then
    N_CH=$(printf '%s\n' "$CHANGES" | awk 'END { print NR }')
    add_note "Working tree: $N_CH uncommitted/untracked change(s) outside docs/; run git status before trusting STATE."
  fi
  [ "$SECONDS" -ge "$GIT_BUDGET" ] && add_note "(git checks stopped early: repository too slow; staleness unknown)"
  [ -z "$NOTE" ] && [ -n "$LAST_STATE_COMMIT" ] && [ -z "$STATE_DIRTY" ] && NOTE="STATE.md is up to date with git (no project commits since its last update)."
elif [ "$AGE_DAYS" -ge "$STALE_DAYS" ]; then
  add_note "WARNING: STATE.md was last modified $AGE_DAYS days ago (no git to compare); verify before relying on it."
fi

# ---- How to use it, depending on why the session started ----
case "$SOURCE" in
  compact)
    HOW="Context was just compacted. The conversation summary is NEWER than this file: where they disagree, trust the summary. Continue the current task without stopping for confirmation; update STATE.md at the next handoff." ;;
  resume)
    HOW="This is a resumed conversation. Its history is newer than this file unless the warnings above say otherwise." ;;
  *)
    HOW="This is a handoff note from an earlier session: a starting hypothesis, not ground truth. If the user's request concerns an item below, confirm your understanding in at most 4 lines before acting and check it against the code/git. If the request is unrelated, do not summarize this note; just help." ;;
esac

echo "=== context-kit: docs/STATE.md (handoff note, auto-injected; $LINES lines, modified $AGE_DAYS day(s) ago) ==="
[ -n "$NOTE" ] && printf '%s\n' "$NOTE"
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
