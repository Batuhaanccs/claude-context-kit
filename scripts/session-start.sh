#!/usr/bin/env bash
# context-kit SessionStart hook, shared by every agent.
#   Claude Code (plugin hook):   session-start.sh                       -> plain text on stdout
#   Antigravity (hooks.json):    session-start.sh --agent antigravity   -> {"injectSteps": [...]} JSON on stdout
# Contract: never fails the session. Any problem -> print nothing and exit 0.
# Only ledgers created by context-kit are injected: STATE.md must carry the "context-kit" marker in its first lines,
# so unrelated STATE.md files are never touched. Symlinked STATE.md files are ignored.

set -u

STATE_MAX_LINES=150 # hard cap on injected STATE lines (protects the context window)
STATE_BUDGET=40     # soft budget; above this we suggest doc-hygiene
AGENT_MAX_LINES=40  # cap on the injected own agent file
GIT_MAX_LINES=15    # cap on listed commits / changed files

AGENT_NAME="claude"
FORMAT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT_NAME="${2:-claude}"; shift ;;
    --format) FORMAT="${2:-}"; shift ;;
  esac
  shift
done
AGENT_NAME=$(printf '%s' "$AGENT_NAME" | tr -cd 'A-Za-z0-9_-')
[ -n "$AGENT_NAME" ] || AGENT_NAME="agent"
if [ -z "$FORMAT" ]; then
  if [ "$AGENT_NAME" = "claude" ]; then FORMAT="text"; else FORMAT="json"; fi
fi

SELF_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || exit 0
KIT_DIR=$(dirname "$SELF_DIR")
CONF_HOME="${CONTEXT_KIT_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/context-kit}"

to_unix() { # Windows path -> POSIX path when running under Git Bash / MSYS
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1" 2>/dev/null || printf '%s' "$1"; else printf '%s' "$1"; fi
}

# --- config (KEY=VALUE lines; never sourced) ---
conf() { # conf <key> <default>
  local v=""
  [ -f "$CONF_HOME/config" ] && v=$(sed -n "s/^$1=//p" "$CONF_HOME/config" 2>/dev/null | tail -n 1 | tr -d '\r')
  if [ -n "$v" ]; then printf '%s' "$v"; else printf '%s' "$2"; fi
}
CTX_DIR=$(conf CTX_DIR "")
CTX_DIR=${CTX_DIR%/}
STALE_HOURS=$(conf STALE_HOURS 4)
case "$STALE_HOURS" in ''|*[!0-9]*) STALE_HOURS=4 ;; esac
ASK_NEW=$(conf ASK_NEW_PROJECTS 1)

# --- hook input (JSON on stdin), parsed without jq ---
INPUT=""
[ -t 0 ] || INPUT=$(cat 2>/dev/null | tr -d '\r\n')
jfield() { printf '%s' "$INPUT" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"; }
SOURCE=$(jfield source | tr -cd 'a-z')
[ -n "$SOURCE" ] || SOURCE="startup"
SID=$(jfield session_id); [ -n "$SID" ] || SID=$(jfield conversationId)
TAG=$(printf '%s' "$SID" | tr -cd 'A-Za-z0-9' | cut -c1-4)
AGENT="$AGENT_NAME"; [ -n "$TAG" ] && AGENT="$AGENT_NAME#$TAG"

ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$ROOT" ]; then
  ROOT=$(printf '%s' "$INPUT" | sed -n 's/.*"workspacePaths"[[:space:]]*:[[:space:]]*\[[[:space:]]*"\([^"]*\)".*/\1/p' | sed 's/\\\\/\\/g')
fi
[ -n "$ROOT" ] || ROOT="$PWD"
ROOT=$(to_unix "$ROOT")
cd "$ROOT" 2>/dev/null || exit 0
ROOT=$(pwd)

# --- keep the shared copy used by other agents in sync with the installed plugin (Claude side only) ---
if [ "$FORMAT" = "text" ] && [ -f "$CONF_HOME/VERSION" ] && [ "$KIT_DIR" != "$CONF_HOME" ] && [ -f "$KIT_DIR/.claude-plugin/plugin.json" ]; then
  KIT_VER=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$KIT_DIR/.claude-plugin/plugin.json" | head -n 1)
  if [ -n "$KIT_VER" ] && [ "$KIT_VER" != "$(tr -d '\r\n' < "$CONF_HOME/VERSION" 2>/dev/null)" ]; then
    bash "$SELF_DIR/ctx.sh" sync >/dev/null 2>&1 </dev/null
  fi
fi

OUT=""
say() { OUT="$OUT$*
"; }
emit() {
  [ -n "$OUT" ] || exit 0
  if [ "$FORMAT" = "json" ]; then
    local esc
    esc=$(printf '%s' "$OUT" | awk 'BEGIN { ORS = "" } { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, ""); if (NR > 1) print "\\n"; print }')
    printf '{"injectSteps":[{"systemMessage":{"systemMessage":"%s"}}]}\n' "$esc"
  else
    printf '%s' "$OUT"
  fi
  exit 0
}

marked() { [ -f "$1/STATE.md" ] && [ ! -L "$1/STATE.md" ] && head -n 5 "$1/STATE.md" 2>/dev/null | grep -q 'context-kit'; }
IS_GIT=0
git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && IS_GIT=1

# --- locate the ledger: private folder (config CTX_DIR) first, then legacy docs/ ---
PRIV=""; WORKTREE_NOTE=""
if [ -n "$CTX_DIR" ]; then
  if marked "$ROOT/$CTX_DIR"; then
    PRIV="$ROOT/$CTX_DIR"
  elif [ "$IS_GIT" = 1 ]; then
    # A linked git worktree does not get the (git-excluded) private folder: use the main worktree's ledger.
    COMMON=$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    if [ -n "$COMMON" ]; then
      MAIN=$(to_unix "$(dirname "$COMMON")")
      if [ "$MAIN" != "$ROOT" ] && marked "$MAIN/$CTX_DIR"; then
        PRIV="$MAIN/$CTX_DIR"
        WORKTREE_NOTE="This is a linked git worktree; the shared ledger lives in the main worktree ($MAIN)."
      fi
    fi
  fi
fi
LEG=""; marked "$ROOT/docs" && LEG="$ROOT/docs"
LEDGER="${PRIV:-$LEG}"

# --- not set up: offer once per project ---
if [ -z "$LEDGER" ]; then
  [ "$SOURCE" = "startup" ] || exit 0
  [ "$ASK_NEW" = "0" ] && exit 0
  HOME_U=$(to_unix "$HOME")
  case "$ROOT" in "$HOME_U"|/|/[a-zA-Z]) exit 0 ;; esac
  LOOKS=0
  for m in .git package.json pyproject.toml requirements.txt Cargo.toml go.mod CMakeLists.txt platformio.ini \
           ProjectSettings/ProjectVersion.txt CLAUDE.md AGENTS.md GEMINI.md README.md; do
    [ -e "$ROOT/$m" ] && { LOOKS=1; break; }
  done
  [ "$LOOKS" = 1 ] || ls "$ROOT"/*.sln >/dev/null 2>&1 || exit 0
  KEY=$(printf '%s' "$ROOT" | tr 'A-Z' 'a-z')
  [ -f "$CONF_HOME/declined" ] && grep -Fxq "$KEY" "$CONF_HOME/declined" 2>/dev/null && exit 0
  CTL="$CONF_HOME/scripts/ctx.sh"; [ -f "$CTL" ] || CTL="$SELF_DIR/ctx.sh"
  say "=== context-kit: not set up in this project ($ROOT) ==="
  say "context-kit gives the agents working here (Claude Code, Antigravity, ...) a shared private ledger: handoff notes, who is working on what, what changed."
  say "Do not interrupt the user's request. At the end of your first reply, ask once in one line (in the user's language) whether to set it up here."
  say "Yes -> run the context-setup skill. No -> run: bash \"$CTL\" decline \"$ROOT\"   (never asked again for this folder)."
  emit
fi

REL="$LEDGER"
case "$LEDGER" in "$ROOT"/*) REL="${LEDGER#"$ROOT"/}" ;; esac
STATE="$LEDGER/STATE.md"
LINES=$(awk 'END { print NR }' "$STATE")
NOW=$(date +%s)
MTIME=$(stat -c %Y "$STATE" 2>/dev/null || stat -f %m "$STATE" 2>/dev/null || echo "$NOW")
AGE_DAYS=$(( (NOW - MTIME) / 86400 )); [ "$AGE_DAYS" -lt 0 ] && AGE_DAYS=0

case "$SOURCE" in
  compact)
    HOW="Context was just compacted. The conversation summary is NEWER than this file: where they disagree, trust the summary. Continue the current task without stopping for confirmation; update the ledger at the next handoff." ;;
  resume)
    HOW="This is a resumed conversation. Its history is newer than this file, but other agents may have worked since: check Claims before changing files." ;;
  *)
    HOW="This is a handoff note from earlier sessions (possibly other agents): a starting hypothesis, not ground truth; it may be outdated if work happened without a handoff. If the user's request concerns an item below, check it against the actual files and confirm your understanding in at most 4 lines before acting. If the request is unrelated, do not summarize this note; just help." ;;
esac

say "=== context-kit: $REL/STATE.md (shared handoff note, auto-injected; $LINES lines, last modified $AGE_DAYS day(s) ago) ==="
say "$HOW"
[ -n "$WORKTREE_NOTE" ] && say "$WORKTREE_NOTE"
[ -n "$PRIV" ] && [ -n "$LEG" ] && say "WARNING: two context-kit ledgers exist ($CTX_DIR/ and docs/). Using $CTX_DIR/. Tell the user and ask which one is current; do not merge them on your own."
if [ -f "$KIT_DIR/protocol/PROTOCOL.md" ]; then
  say ""
  if [ -n "$PRIV" ]; then NOTE="private, git-ignored: never commit it, never copy its content into tracked files"
  else NOTE="project docs folder: commit ledger files only if the project already versions them"; fi
  say "$(sed -e "s|{{LEDGER_NOTE}}|$NOTE|g" -e "s|{{AGENT}}|$AGENT|g" -e "s|{{AGENT_NAME}}|$AGENT_NAME|g" -e "s|{{LEDGER}}|$REL|g" -e "s|{{STALE_HOURS}}|$STALE_HOURS|g" "$KIT_DIR/protocol/PROTOCOL.md")"
fi
say "---"
say "$(head -n "$STATE_MAX_LINES" "$STATE")"
if [ "$LINES" -gt "$STATE_MAX_LINES" ]; then
  say "--- [truncated at $STATE_MAX_LINES of $LINES lines: read $REL/STATE.md for the rest, then suggest doc-hygiene] ---"
elif [ "$LINES" -gt "$STATE_BUDGET" ]; then
  say "--- [STATE.md is $LINES lines, budget $STATE_BUDGET: suggest doc-hygiene at a natural pause] ---"
fi

# --- claims older than the stale limit ---
STALE=$(awk '/^## Claims/ { c = 1; next } /^## / { c = 0 } c && /^- \*\*/' "$STATE" | while IFS= read -r line; do
  ts=$(printf '%s' "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}' | head -n 1)
  [ -n "$ts" ] || continue
  t=$(date -d "$ts" +%s 2>/dev/null || date -j -f '%Y-%m-%d %H:%M' "$ts" +%s 2>/dev/null) || continue
  h=$(( (NOW - t) / 3600 ))
  [ "$h" -ge "$STALE_HOURS" ] && printf '%s\n' "- ${h}h old: ${line#- }"
done)
[ -n "$STALE" ] && { say "--- Claims older than ${STALE_HOURS}h (maybe abandoned; ask the user before removing):"; say "$STALE"; }

if [ "$SOURCE" != "compact" ]; then
  # --- this agent's own handoff file; the others are listed, read them when relevant ---
  OWN="$LEDGER/agents/$AGENT_NAME.md"
  if [ -f "$OWN" ]; then
    say "--- Your handoff file ($REL/agents/$AGENT_NAME.md):"
    say "$(head -n "$AGENT_MAX_LINES" "$OWN")"
  fi
  OTHERS=""
  for f in "$LEDGER"/agents/*.md; do
    [ -f "$f" ] || continue
    n=$(basename "$f" .md); [ "$n" = "$AGENT_NAME" ] && continue
    m=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo "$NOW")
    OTHERS="$OTHERS $n (updated $(( (NOW - m) / 3600 ))h ago),"
  done
  [ -n "$OTHERS" ] && say "--- Other agents' handoff files in $REL/agents/:${OTHERS%,}. Read one when its work is relevant."

  # --- what changed since the last handoff (git, optional) ---
  if [ "$IS_GIT" = 1 ] && [ "$SOURCE" != "resume" ]; then
    BASE=$(sed -n 's/^Git-base:[[:space:]]*\([0-9a-fA-F]\{4,40\}\).*/\1/p' "$STATE" | head -n 1)
    if [ -n "$BASE" ] && git -C "$ROOT" cat-file -e "$BASE^{commit}" 2>/dev/null; then
      COUNT=$(git -C "$ROOT" rev-list --count "$BASE..HEAD" 2>/dev/null || echo 0)
      if [ "$COUNT" -gt 0 ] 2>/dev/null; then
        say "--- Git: $COUNT commit(s) since the last handoff (Git-base $BASE); [agent] from journal.md when known:"
        say "$(git -C "$ROOT" log --format='%h %an: %s' -n "$GIT_MAX_LINES" "$BASE..HEAD" 2>/dev/null | while IFS= read -r l; do
          h=${l%% *}; a=""
          [ -f "$LEDGER/journal.md" ] && a=$(grep -F "| $h" "$LEDGER/journal.md" 2>/dev/null | head -n 1 | awk -F'|' '{ gsub(/ /, "", $2); print $2 }')
          if [ -n "$a" ]; then printf '  %s  [%s]\n' "$l" "$a"; else printf '  %s\n' "$l"; fi
        done)"
      fi
    fi
    CHANGED=$(git -C "$ROOT" status --porcelain 2>/dev/null)
    if [ -n "$CHANGED" ]; then
      NCH=$(printf '%s\n' "$CHANGED" | awk 'END { print NR }')
      say "--- Git: $NCH uncommitted change(s) in the working tree (compare with the Touched lists; unexplained ones -> ask):"
      say "$(printf '%s\n' "$CHANGED" | head -n "$GIT_MAX_LINES" | sed 's/^/  /')"
      [ "$NCH" -gt "$GIT_MAX_LINES" ] && say "  ... ($((NCH - GIT_MAX_LINES)) more: run git status)"
    fi
  fi
fi

say "=== end of context-kit. You are $AGENT. Claim before changing files; save state with the handoff skill (\"handoff\" / \"devret\") before ending. ==="
emit
