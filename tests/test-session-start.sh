#!/usr/bin/env bash
# Tests for scripts/session-start.sh. Run: bash tests/test-session-start.sh
# Creates throwaway projects in a temp dir; touches nothing else.

HOOK="$(cd "$(dirname "$0")/.." && pwd)/scripts/session-start.sh"
CTL="$(cd "$(dirname "$0")/.." && pwd)/scripts/ctx.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export CONTEXT_KIT_HOME="$TMP/ck" GEMINI_HOME="$TMP/gem" XDG_CONFIG_HOME="$TMP/xdg"; unset CLAUDE_PROJECT_DIR
PASS=0; FAIL=0

run() { # run <project dir> <source> -> hook stdout
  printf '{"session_id":"t","hook_event_name":"SessionStart","source":"%s"}' "$2" |
    CLAUDE_PROJECT_DIR="$1" bash "$HOOK"
}
ok()   { PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
check() { # check <name> <output> <grep -E pattern> [absent]
  if [ "${4:-}" = absent ]; then
    printf '%s' "$2" | grep -Eq -- "$3" && { bad "$1 (unexpected: $3)"; return; }
  else
    printf '%s' "$2" | grep -Eq -- "$3" || { bad "$1 (missing: $3)"; return; }
  fi
  ok
}
silent() { [ -z "$2" ] && ok || bad "$1 should be silent"; }
mkproj() { mkdir -p "$TMP/$1/docs"; printf '# State\n<!-- context-kit -->\nUpdated: today\n- **Work A**: step 2. Next: do X.\n' > "$TMP/$1/docs/STATE.md"; echo "$TMP/$1"; }

# Activation
mkdir -p "$TMP/empty"; silent "no STATE" "$(run "$TMP/empty" startup)"
mkdir -p "$TMP/foreign/docs"; printf '# State machine\nIdle -> Running\n' > "$TMP/foreign/docs/STATE.md"
silent "STATE without marker" "$(run "$TMP/foreign" startup)"
P=$(mkproj link); mv "$P/docs/STATE.md" "$P/real.md"
if ln -s "$P/real.md" "$P/docs/STATE.md" 2>/dev/null && [ -L "$P/docs/STATE.md" ]; then
  silent "symlinked STATE" "$(run "$P" startup)"
fi

# Content and guidance per source
P=$(mkproj basic); OUT=$(run "$P" startup)
check "injects state" "$OUT" "Work A"
check "startup guidance" "$OUT" "starting hypothesis"
check "no git section outside git" "$OUT" "^--- Git:" absent
check "compact guidance" "$(run "$P" compact)" "summary is NEWER"
check "compact no confirm" "$(run "$P" compact)" "starting hypothesis" absent
check "resume guidance" "$(run "$P" resume)" "resumed conversation"
check "clear guidance" "$(run "$P" clear)" "starting hypothesis"

# Robustness
OUT=$(printf 'garbage' | CLAUDE_PROJECT_DIR="$P" bash "$HOOK"); RC=$?
check "garbage stdin default" "$OUT" "starting hypothesis"
[ $RC -eq 0 ] && ok || bad "exit code $RC"
if command -v cygpath >/dev/null 2>&1; then
  check "windows path" "$(run "$(cygpath -w "$P")" startup)" "Work A"
fi
P=$(mkproj utf8); echo "- Şu an: ağaç kaynağı kararı bekleniyor" >> "$P/docs/STATE.md"
check "utf8 content" "$(run "$P" startup)" "ağaç kaynağı"
P=$(mkproj nonl); printf -- '- LAST LINE' >> "$P/docs/STATE.md"
check "no-newline last line kept" "$(run "$P" startup)" "^- LAST LINE$"

# Age
P=$(mkproj old); touch -t "$(date -v-30d +%Y%m%d%H%M 2>/dev/null || date -d '30 days ago' +%Y%m%d%H%M)" "$P/docs/STATE.md"
check "age shown" "$(run "$P" startup)" "last modified 30 day"
P=$(mkproj future); touch -t "$(date -v+3d +%Y%m%d%H%M 2>/dev/null || date -d '3 days' +%Y%m%d%H%M)" "$P/docs/STATE.md"
check "future mtime clamped" "$(run "$P" startup)" "last modified 0 day"

# Budgets: over 40 -> hint; over 150 -> truncated with explicit note
P=$(mkproj long); for i in $(seq 1 60); do echo "- line $i" >> "$P/docs/STATE.md"; done
check "budget hint" "$(run "$P" startup)" "budget 40"
for i in $(seq 61 200); do echo "- line $i" >> "$P/docs/STATE.md"; done
OUT=$(run "$P" startup)
check "truncation note" "$OUT" "truncated at 150"
check "truncated content absent" "$OUT" "line 190" absent

# ---------- multi-agent (v0.3) ----------
gitproj() { mkdir -p "$TMP/$1" && git -C "$TMP/$1" init -q && echo a > "$TMP/$1/a.txt" &&
  git -C "$TMP/$1" add a.txt && git -C "$TMP/$1" -c user.name=T -c user.email=t@t commit -qm init; echo "$TMP/$1"; }
agrun() { # agrun <project dir> -> Antigravity-style hook stdout
  printf '{"conversationId":"ec33ebf9","workspacePaths":["%s"],"modelName":"m"}' "$1" | bash "$HOOK" --agent antigravity
}

# Offer to set up: only in folders that look like projects, only on startup, never after decline
P=$(gitproj offer)
check "offer in git project" "$(run "$P" startup)" "not set up in this project"
silent "no offer on compact" "$(run "$P" compact)"
bash "$CTL" decline "$P" >/dev/null
silent "no offer after decline" "$(run "$P" startup)"

# Machine install into the temp homes (never the real ones)
HOME="$TMP/home" bash "$CTL" install --name _tester >/dev/null 2>&1
[ -f "$TMP/ck/config" ] && grep -q '^CTX_DIR=_tester/ctx$' "$TMP/ck/config" && ok || bad "install writes config"
grep -Fxq '_tester/' "$TMP/xdg/git/ignore" && ok || bad "install adds global git exclude"
grep -q '"context-kit"' "$TMP/gem/config/hooks.json" && grep -q -- '--agent antigravity' "$TMP/gem/config/hooks.json" && ok || bad "install writes Antigravity hook"
[ -f "$TMP/gem/config/skills/handoff/SKILL.md" ] && ok || bad "install copies skills for Antigravity"
grep -q 'context-kit:start' "$TMP/gem/GEMINI.md" && ok || bad "install adds GEMINI.md fallback"
HOME="$TMP/home" bash "$CTL" install >/dev/null 2>&1
[ "$(grep -c '"context-kit"' "$TMP/gem/config/hooks.json")" = 1 ] && [ "$(grep -c 'context-kit:start' "$TMP/gem/GEMINI.md")" = 1 ] && ok || bad "install is idempotent"

# Private ledger
P=$(gitproj priv)
bash "$CTL" init "$P" >/dev/null
[ -f "$P/_tester/ctx/STATE.md" ] && [ -f "$P/_tester/ctx/journal.md" ] && ok || bad "init creates ledger"
[ -z "$(git -C "$P" status --porcelain)" ] && ok || bad "private ledger invisible to git"
grep -q "^Git-base: $(git -C "$P" rev-parse --short HEAD)$" "$P/_tester/ctx/STATE.md" && ok || bad "init sets Git-base"
grep -q '<work name>' "$P/_tester/ctx/STATE.md" && grep -q '^- \*\*<work name>\*\*' "$P/_tester/ctx/STATE.md" && bad "init leaves example lines" || ok
OUT=$(run "$P" startup)
check "private ledger injected" "$OUT" "_tester/ctx/STATE.md"
check "protocol injected" "$OUT" "Multi-agent protocol"
check "no unrequested git actions" "$OUT" "never push"
check "automatic task-done update" "$OUT" "Task done (automatic"
check "agent id" "$OUT" "You are claude#t"
check "private ledger note" "$OUT" "private, git-ignored"
check "no placeholder left" "$OUT" "\{\{" absent
check "docs ledger note" "$(run "$(mkproj docsnote)" startup)" "project docs folder"

# Claims, agent files, journal-annotated commits, uncommitted changes
L="$P/_tester/ctx"
OLD=$(date -d '6 hours ago' '+%Y-%m-%d %H:%M' 2>/dev/null || date -v-6H '+%Y-%m-%d %H:%M')
sed -i.bak "s|^## Claims.*|&\n- **Climb test** \| claude#ab12 \| $OLD \| paths: Assets/Climb/ \| resources: unity-editor \| test|" "$L/STATE.md"
printf '# Agent handoff: claude\n## Climb test\n- Next: OWNNOTE\n' > "$L/agents/claude.md"
printf '# Agent handoff: antigravity\n## UI\n- Next: AGNOTE\n' > "$L/agents/antigravity.md"
echo b > "$P/b.txt"; git -C "$P" add b.txt; git -C "$P" -c user.name=T -c user.email=t@t commit -qm "add ui"
echo "2026-01-01 10:00 | antigravity#ec33 | $(git -C "$P" rev-parse --short HEAD) | add ui" >> "$L/journal.md"
echo dirty > "$P/c.txt"
OUT=$(run "$P" startup)
check "stale claim flagged" "$OUT" "6h old: \*\*Climb test"
check "own agent file injected" "$OUT" "OWNNOTE"
check "other agent file only listed" "$OUT" "AGNOTE" absent
check "other agent listed" "$OUT" "antigravity \(updated"
check "commit since base, annotated" "$OUT" "add ui  \[antigravity#ec33\]"
check "uncommitted change listed" "$OUT" "\?\? c.txt"
check "no git delta on compact" "$(run "$P" compact)" "^--- Git:" absent

# Antigravity: JSON injectSteps on one line, own agent file is antigravity's
OUT=$(agrun "$P")
check "json shape" "$OUT" '^\{"injectSteps":\[\{"systemMessage":\{"systemMessage":"'
[ "$(printf '%s\n' "$OUT" | awk 'END { print NR }')" = 1 ] && ok || bad "json is a single line"
check "json own agent file" "$OUT" "AGNOTE"
check "json agent id" "$OUT" "You are antigravity#ec33"
if command -v cygpath >/dev/null 2>&1; then
  WP=$(cygpath -w "$P"); check "json windows workspace path" "$(agrun "${WP//\\/\\\\}")" "_tester/ctx/STATE.md"
fi
PY=""; for c in python3 python; do "$c" -c '' >/dev/null 2>&1 && { PY=$c; break; }; done
if [ -n "$PY" ]; then
  printf '%s' "$OUT" | "$PY" -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && ok || bad "json parses"
fi

# Two ledgers -> warning; linked worktree -> main worktree's ledger
mkdir -p "$P/docs"; printf '# State\n<!-- context-kit -->\n' > "$P/docs/STATE.md"
check "two ledgers warned" "$(run "$P" startup)" "two context-kit ledgers"
rm -rf "$P/docs"
git -C "$P" worktree add -q "$TMP/wt" -b side 2>/dev/null
check "worktree uses main ledger" "$(run "$TMP/wt" startup)" "linked git worktree"

echo "passed: $PASS, failed: $FAIL"
[ $FAIL -eq 0 ]
