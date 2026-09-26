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
check() { # check <name> <output> <grep -E pattern> [absent]
  if [ "${4:-}" = absent ]; then
    printf '%s' "$2" | grep -Eq -- "$3" && { echo "FAIL: $1 (unexpected: $3)"; FAIL=$((FAIL+1)); return; }
  else
    printf '%s' "$2" | grep -Eq -- "$3" || { echo "FAIL: $1 (missing: $3)"; FAIL=$((FAIL+1)); return; }
  fi
  PASS=$((PASS+1))
}
mkproj() { mkdir -p "$TMP/$1/docs"; printf '# State\n<!-- context-kit -->\nUpdated: today\n- **Work A**: step 2. Next: do X.\n' > "$TMP/$1/docs/STATE.md"; echo "$TMP/$1"; }
gitc() { git -C "$1" -c user.name=t -c user.email=t@t commit -qm "$2" --allow-empty; }

# 1. No STATE.md -> silent
mkdir -p "$TMP/empty"
OUT=$(run "$TMP/empty" startup); [ -z "$OUT" ] && PASS=$((PASS+1)) || { echo "FAIL: no-state should be silent"; FAIL=$((FAIL+1)); }

# 2. STATE, no git, fresh
P=$(mkproj nogit); OUT=$(run "$P" startup)
check "nogit injects state" "$OUT" "Work A"
check "nogit startup guidance" "$OUT" "starting hypothesis"
check "nogit no warning" "$OUT" "WARNING" absent

# 3. STATE, no git, old
P=$(mkproj old); touch -t "$(date -v-30d +%Y%m%d%H%M 2>/dev/null || date -d '30 days ago' +%Y%m%d%H%M)" "$P/docs/STATE.md"; OUT=$(run "$P" startup)
check "old warns by age" "$OUT" "WARNING: STATE.md was last modified 30 days ago"

# 4. git: STATE committed, then 2 more commits
P=$(mkproj gitstale); git -C "$P" init -q; git -C "$P" add -A; gitc "$P" "add state"
for n in one two; do echo "$n" > "$P/f-$n.txt"; git -C "$P" add -A; gitc "$P" "feat $n"; done
OUT=$(run "$P" startup)
check "git stale count" "$OUT" "WARNING: 2 project commit\(s\) since STATE.md"
check "git stale lists subjects" "$OUT" "feat two"

# 5. git: STATE committed last -> up to date
P=$(mkproj gitfresh); git -C "$P" init -q; gitc "$P" "code"; git -C "$P" add -A; gitc "$P" "handoff"
OUT=$(run "$P" startup)
check "git fresh" "$OUT" "up to date with git"

# 6. git: STATE edited (dirty) after last commit -> no commit warning
P=$(mkproj gitdirty); git -C "$P" init -q; git -C "$P" add -A; gitc "$P" "state"; gitc "$P" "code"
sleep 1; echo "- new line" >> "$P/docs/STATE.md"; OUT=$(run "$P" startup)
check "dirty newer state not stale" "$OUT" "WARNING: [0-9]+ commit" absent

# 7. Uncommitted code changes outside docs/
P=$(mkproj gitwt); echo a > "$P/code.txt"; git -C "$P" init -q; git -C "$P" add -A; gitc "$P" "all"; echo b > "$P/code.txt"
OUT=$(run "$P" startup)
check "working tree note" "$OUT" "1 uncommitted/untracked change"

# 8. Source-specific guidance
P=$(mkproj src)
check "compact guidance" "$(run "$P" compact)" "summary is NEWER"
check "compact no confirm" "$(run "$P" compact)" "starting hypothesis" absent
check "resume guidance" "$(run "$P" resume)" "resumed conversation"
check "clear guidance" "$(run "$P" clear)" "starting hypothesis"

# 9. Missing / malformed stdin -> defaults to startup, still exits 0
OUT=$(printf 'garbage' | CLAUDE_PROJECT_DIR="$P" bash "$HOOK"); RC=$?
check "garbage stdin default" "$OUT" "starting hypothesis"
[ $RC -eq 0 ] && PASS=$((PASS+1)) || { echo "FAIL: exit code $RC"; FAIL=$((FAIL+1)); }

# 10. Budgets: over 40 -> hint; over 150 -> truncated with explicit note
P=$(mkproj long); for i in $(seq 1 60); do echo "- line $i" >> "$P/docs/STATE.md"; done
check "budget hint" "$(run "$P" startup)" "budget 40"
for i in $(seq 61 200); do echo "- line $i" >> "$P/docs/STATE.md"; done
OUT=$(run "$P" startup)
check "truncation note" "$OUT" "truncated at 150"
check "truncated content absent" "$OUT" "line 190" absent

# 11. Windows-style project path (backslashes), only where cygpath exists
if command -v cygpath >/dev/null 2>&1; then
  P=$(mkproj winpath); OUT=$(run "$(cygpath -w "$P")" startup)
  check "windows path" "$OUT" "Work A"
fi

# 12. Non-ASCII content survives
P=$(mkproj utf8); echo "- Şu an: ağaç kaynağı kararı bekleniyor" >> "$P/docs/STATE.md"
check "utf8 content" "$(run "$P" startup)" "ağaç kaynağı"

# 13. No context-kit marker -> silent (an unrelated docs/STATE.md in some repo)
mkdir -p "$TMP/foreign/docs"; printf '# State machine\nIdle -> Running\n' > "$TMP/foreign/docs/STATE.md"
OUT=$(run "$TMP/foreign" startup); [ -z "$OUT" ] && PASS=$((PASS+1)) || { echo "FAIL: foreign STATE must be ignored"; FAIL=$((FAIL+1)); }

# 14. Symlinked STATE -> silent (where symlinks are real)
P=$(mkproj link); mv "$P/docs/STATE.md" "$P/real.md"
if ln -s "$P/real.md" "$P/docs/STATE.md" 2>/dev/null && [ -L "$P/docs/STATE.md" ]; then
  OUT=$(run "$P" startup); [ -z "$OUT" ] && PASS=$((PASS+1)) || { echo "FAIL: symlinked STATE must be ignored"; FAIL=$((FAIL+1)); }
fi

# 15. Docs-only commits after STATE are not staleness
P=$(mkproj docsonly); git -C "$P" init -q; git -C "$P" add -A; gitc "$P" "state"
echo "- x" > "$P/docs/LESSONS.md"; git -C "$P" add -A; gitc "$P" "lessons only"
OUT=$(run "$P" startup)
check "docs-only commit not stale" "$OUT" "WARNING" absent
check "docs-only commit fresh" "$OUT" "up to date with git"

# 16. Project in a subfolder of a repo: other folders' commits and changes do not count
mkdir -p "$TMP/mono"; git -C "$TMP/mono" init -q; P=$(mkproj mono/app); mkdir -p "$TMP/mono/other"
git -C "$TMP/mono" add -A; gitc "$TMP/mono" "state"
echo x > "$TMP/mono/other/a.txt"; git -C "$TMP/mono" add -A; gitc "$TMP/mono" "other package"; echo y > "$TMP/mono/other/b.txt"
sleep 1; echo "- edit" >> "$P/docs/STATE.md"
OUT=$(run "$P" startup)
check "monorepo other commits ignored" "$OUT" "WARNING" absent
check "monorepo other changes ignored" "$OUT" "Working tree" absent

# 17. Dirty STATE does not mask project commits since its last committed version
P=$(mkproj dirtymask); git -C "$P" init -q; git -C "$P" add -A; gitc "$P" "state"
echo 1 > "$P/c.txt"; git -C "$P" add -A; gitc "$P" "feature X"; sleep 1; echo "- small edit" >> "$P/docs/STATE.md"
OUT=$(run "$P" startup)
check "dirty state note" "$OUT" "uncommitted edits; 1 project commit"
check "dirty state never 'up to date'" "$OUT" "up to date" absent

# 18. Untracked new code file is reported
P=$(mkproj untracked); git -C "$P" init -q; git -C "$P" add -A; gitc "$P" "state"; echo n > "$P/new.py"
check "untracked reported" "$(run "$P" startup)" "1 uncommitted/untracked"

# 19. STATE without trailing newline: last line kept and separated
P=$(mkproj nonl); printf -- '- LAST LINE' >> "$P/docs/STATE.md"
OUT=$(run "$P" startup)
check "no-newline last line kept" "$OUT" "^- LAST LINE$"

# 20. Future mtime -> age clamped to 0
P=$(mkproj future); touch -t "$(date -v+3d +%Y%m%d%H%M 2>/dev/null || date -d '3 days' +%Y%m%d%H%M)" "$P/docs/STATE.md"
check "future mtime clamped" "$(run "$P" startup)" "modified 0 day"

echo "passed: $PASS, failed: $FAIL"
[ $FAIL -eq 0 ]
