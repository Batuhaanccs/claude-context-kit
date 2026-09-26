#!/usr/bin/env bash
# Tests for scripts/session-start.sh. Run: bash tests/test-session-start.sh
# Creates throwaway projects in a temp dir; touches nothing else.

HOOK="$(cd "$(dirname "$0")/.." && pwd)/scripts/session-start.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
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
check "no git talk" "$OUT" "commit|git" absent
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

echo "passed: $PASS, failed: $FAIL"
[ $FAIL -eq 0 ]
