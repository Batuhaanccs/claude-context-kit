#!/usr/bin/env bash
# context-kit control script (agent-independent). Usage:
#   ctx.sh install [--name _you] [--no-antigravity]   one-time machine setup (config, git exclude, shared copy, Antigravity)
#   ctx.sh init [--docs] [project-dir]                create the ledger in a project (never overwrites)
#   ctx.sh decline [project-dir]                      never offer setup for this folder again
#   ctx.sh sync                                       refresh the shared copy (+ Antigravity skills) from the plugin
#   ctx.sh status [project-dir]                       show what is configured
# Config: ${XDG_CONFIG_HOME:-~/.config}/context-kit/config (KEY=VALUE: CTX_DIR, STALE_HOURS, ASK_NEW_PROJECTS).

set -u

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
KIT_DIR=$(dirname "$SELF_DIR")
CONF_HOME="${CONTEXT_KIT_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/context-kit}"
GEMINI_HOME="${GEMINI_HOME:-$HOME/.gemini}"
AG_SKILLS="$GEMINI_HOME/config/skills"
AG_HOOKS="$GEMINI_HOME/config/hooks.json"
SKILLS="context-setup handoff resume-work doc-hygiene"

die() { echo "ctx: $*" >&2; exit 1; }
to_unix() { if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1" 2>/dev/null || printf '%s' "$1"; else printf '%s' "$1"; fi; }
to_mixed() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; else printf '%s' "$1"; fi; }
conf() {
  local v=""
  [ -f "$CONF_HOME/config" ] && v=$(sed -n "s/^$1=//p" "$CONF_HOME/config" | tail -n 1 | tr -d '\r')
  if [ -n "$v" ]; then printf '%s' "$v"; else printf '%s' "$2"; fi
}
kit_version() { sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$KIT_DIR/.claude-plugin/plugin.json" 2>/dev/null | head -n 1; }
now() { date "+%Y-%m-%d %H:%M"; }

# Copy the agent-independent parts of the kit to CONF_HOME, so agents other than Claude can use them.
cmd_sync() {
  [ "$KIT_DIR" = "$CONF_HOME" ] && { echo "ctx: running from the shared copy; nothing to sync"; return 0; }
  mkdir -p "$CONF_HOME/scripts" "$CONF_HOME/protocol" "$CONF_HOME/skills" || die "cannot create $CONF_HOME"
  cp "$KIT_DIR/scripts/session-start.sh" "$KIT_DIR/scripts/ctx.sh" "$CONF_HOME/scripts/"
  cp "$KIT_DIR/protocol/PROTOCOL.md" "$CONF_HOME/protocol/"
  for s in $SKILLS; do rm -rf "$CONF_HOME/skills/$s"; cp -R "$KIT_DIR/skills/$s" "$CONF_HOME/skills/"; done
  if [ -f "$CONF_HOME/antigravity" ]; then
    for s in $SKILLS; do rm -rf "${AG_SKILLS:?}/$s"; cp -R "$KIT_DIR/skills/$s" "$AG_SKILLS/"; done
  fi
  kit_version > "$CONF_HOME/VERSION"
  echo "ctx: shared copy updated in $CONF_HOME (v$(kit_version))"
}

# Add a line to the user's global git exclude file (git reads ~/.config/git/ignore when core.excludesFile is unset).
git_exclude() {
  command -v git >/dev/null 2>&1 || { echo "ctx: git not found; skipped global exclude"; return 0; }
  local f
  f=$(git config --global --get core.excludesFile 2>/dev/null)
  if [ -n "$f" ]; then f=$(to_unix "${f/#\~/$HOME}"); else f="${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"; fi
  mkdir -p "$(dirname "$f")"; touch "$f"
  for p in "$@"; do
    grep -Fxq "$p" "$f" || { [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ] && echo >> "$f"; echo "$p" >> "$f"; echo "ctx: global git exclude += $p ($f)"; }
  done
}

ag_hook_command() {
  local bash_exe script
  script=$(to_mixed "$CONF_HOME/scripts/session-start.sh")
  if command -v cygpath >/dev/null 2>&1; then
    bash_exe="$(cygpath -m /)/bin/bash.exe"
    [ -f "$(to_unix "$bash_exe")" ] || bash_exe=$(cygpath -m "$(command -v bash)")
    # Short (8.3) path: no spaces, so the command works whether Antigravity runs it via cmd, PowerShell or sh.
    bash_exe=$(cygpath -m "$(cygpath -d "$bash_exe" 2>/dev/null || printf '%s' "$bash_exe")")
  else
    bash_exe="bash"
  fi
  printf '%s %s --agent antigravity' "$bash_exe" "$script"
}

install_antigravity() {
  mkdir -p "$AG_SKILLS" "$(dirname "$AG_HOOKS")" || die "cannot create $GEMINI_HOME/config"
  for s in $SKILLS; do rm -rf "${AG_SKILLS:?}/$s"; cp -R "$KIT_DIR/skills/$s" "$AG_SKILLS/"; done
  echo "ctx: Antigravity skills installed in $AG_SKILLS ($SKILLS)"
  local cmd entry
  cmd=$(ag_hook_command | sed 's/\\/\\\\/g; s/"/\\"/g')
  entry="\"context-kit\": {\"SessionStart\": [{\"type\": \"command\", \"command\": \"$cmd\", \"timeout\": 15}]}"
  if [ ! -s "$AG_HOOKS" ]; then
    printf '{\n  %s\n}\n' "$entry" > "$AG_HOOKS"
    echo "ctx: Antigravity hook written: $AG_HOOKS"
  elif grep -q '"context-kit"' "$AG_HOOKS"; then
    echo "ctx: Antigravity hook already present in $AG_HOOKS (left as is)"
  elif tr -d ' \t\r\n' < "$AG_HOOKS" | grep -q '^{}$'; then
    cp "$AG_HOOKS" "$AG_HOOKS.bak-$(date +%Y%m%d)"
    printf '{\n  %s\n}\n' "$entry" > "$AG_HOOKS"
    echo "ctx: Antigravity hook written: $AG_HOOKS"
  elif tr -d ' \t\r\n' < "$AG_HOOKS" | grep -q '^{'; then
    cp "$AG_HOOKS" "$AG_HOOKS.bak-$(date +%Y%m%d)"
    awk -v e="$entry" 'done != 1 && sub(/\{/, "{\n  " e ",") { done = 1 } { print }' "$AG_HOOKS.bak-$(date +%Y%m%d)" > "$AG_HOOKS"
    echo "ctx: Antigravity hook added to existing $AG_HOOKS (backup: .bak-$(date +%Y%m%d))"
  else
    echo "ctx: WARNING: $AG_HOOKS is not a JSON object; add this entry by hand: {$entry}"
  fi
  # Fallback rule, in case the hook does not run: global GEMINI.md block between markers.
  local gm="$GEMINI_HOME/GEMINI.md" ctx
  ctx=$(conf CTX_DIR "")
  touch "$gm"
  if ! grep -q 'context-kit:start' "$gm"; then
    [ -s "$gm" ] && printf '\n' >> "$gm"
    cat >> "$gm" <<EOF
<!-- context-kit:start (managed by context-kit; keep short) -->
## Shared agent ledger (context-kit)
- At the start of a conversation a context-kit system message is normally injected by a hook. If it is missing and the
  workspace has \`${ctx:-<private>/ctx}/STATE.md\` or \`docs/STATE.md\` containing "context-kit", read it and follow
  \`$(to_mixed "$CONF_HOME")/protocol/PROTOCOL.md\` before changing files (you are agent \`antigravity\`).
- Never add agent names, co-author lines or AI trailers to commits. Never commit the ledger folder.
- End of a work session: use the handoff skill ("devret").
<!-- context-kit:end -->
EOF
    echo "ctx: fallback rule added to $gm"
  fi
  date "+%Y-%m-%d" > "$CONF_HOME/antigravity"
}

cmd_install() {
  local name="" ag=1
  while [ $# -gt 0 ]; do
    case "$1" in
      --name) name="${2:-}"; shift ;;
      --no-antigravity) ag=0 ;;
      *) die "unknown option: $1" ;;
    esac
    shift
  done
  mkdir -p "$CONF_HOME" || die "cannot create $CONF_HOME"
  if [ ! -f "$CONF_HOME/config" ]; then
    if [ -z "$name" ]; then
      name=$(git config --global user.name 2>/dev/null | awk '{ print tolower($1) }' | tr -cd 'a-z0-9')
      [ -n "$name" ] || name=$(printf '%s' "${USER:-${USERNAME:-me}}" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9')
      name="_$name"
    fi
    name=$(printf '%s' "$name" | tr -cd 'A-Za-z0-9_.-')
    [ -n "$name" ] || die "invalid --name"
    printf 'CTX_DIR=%s/ctx\nSTALE_HOURS=4\nASK_NEW_PROJECTS=1\n' "$name" > "$CONF_HOME/config"
    echo "ctx: config written: $CONF_HOME/config (ledger folder: $name/ctx)"
  else
    echo "ctx: config exists: $CONF_HOME/config (CTX_DIR=$(conf CTX_DIR '?'))"
  fi
  local top
  top=$(conf CTX_DIR "" | cut -d/ -f1)
  [ -n "$top" ] && git_exclude "$top/" "CLAUDE.local.md"
  cmd_sync
  if [ "$ag" = 1 ]; then install_antigravity; fi
  echo "ctx: done. In a project: say \"bağlam sistemini kur\" / \"set up context-kit\", or run: bash \"$CONF_HOME/scripts/ctx.sh\" init"
}

cmd_init() {
  local mode="private" root=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --docs) mode="docs" ;;
      --private) mode="private" ;;
      *) root="$1" ;;
    esac
    shift
  done
  root=$(to_unix "${root:-$PWD}")
  cd "$root" 2>/dev/null || die "no such folder: $root"
  root=$(pwd)
  local ledger tpl="$KIT_DIR/skills/context-setup/templates"
  if [ "$mode" = "docs" ]; then
    ledger="$root/docs"
  else
    local ctx
    ctx=$(conf CTX_DIR "")
    [ -n "$ctx" ] || die "no CTX_DIR configured; run: ctx.sh install --name _yourname (or use --docs)"
    ledger="$root/${ctx%/}"
  fi
  [ -f "$ledger/STATE.md" ] && ! head -n 5 "$ledger/STATE.md" | grep -q 'context-kit' &&
    die "$ledger/STATE.md exists and is not a context-kit file; not touching it"
  mkdir -p "$ledger/agents" || die "cannot create $ledger"
  local base="-" created=""
  git -C "$root" rev-parse --verify -q HEAD >/dev/null 2>&1 && base=$(git -C "$root" rev-parse --short HEAD)
  if [ ! -f "$ledger/STATE.md" ]; then
    awk -v t="$(now)" -v b="$base" '
      /^Updated:/ { print "Updated: " t; next }
      /^Git-base:/ { print "Git-base: " b; next }
      /^- (\*\*|\[)<work name>/ { if (sec == "Active work") print "- (no active work yet)"; next }
      /^## / { sec = substr($0, 4) }
      { print }' "$tpl/STATE.template.md" > "$ledger/STATE.md"
    created="$created STATE.md"
  fi
  [ -f "$ledger/journal.md" ] || { cp "$tpl/JOURNAL.template.md" "$ledger/journal.md"; created="$created journal.md"; }
  # Private mode in a git repo: make sure the ledger can never be committed.
  if [ "$mode" = "private" ] && git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git -C "$root" check-ignore -q "$ledger/STATE.md"; then
      local ex top
      ex=$(to_unix "$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)")/info/exclude
      top=$(conf CTX_DIR "" | cut -d/ -f1)
      mkdir -p "$(dirname "$ex")"; touch "$ex"
      grep -Fxq "$top/" "$ex" || { echo "$top/" >> "$ex"; echo "ctx: added $top/ to $ex"; }
    fi
    git -C "$root" check-ignore -q "$ledger/STATE.md" || echo "ctx: WARNING: $ledger is NOT ignored by git; do not commit it"
  fi
  local rel="${ledger#"$root"/}"
  if [ -n "$created" ]; then echo "ctx: created in $rel/:$created (agents/ for handoff files)"; else echo "ctx: ledger already exists in $rel/ (nothing changed)"; fi
}

cmd_decline() {
  local root
  root=$(to_unix "${1:-$PWD}")
  root=$(cd "$root" 2>/dev/null && pwd) || die "no such folder"
  mkdir -p "$CONF_HOME"
  local key
  key=$(printf '%s' "$root" | tr 'A-Z' 'a-z')
  grep -Fxq "$key" "$CONF_HOME/declined" 2>/dev/null || echo "$key" >> "$CONF_HOME/declined"
  echo "ctx: will not offer setup for $root again (undo: remove the line from $CONF_HOME/declined)"
}

cmd_status() {
  local root
  root=$(to_unix "${1:-$PWD}")
  echo "plugin:      $KIT_DIR (v$(kit_version))"
  echo "shared copy: $CONF_HOME (v$(cat "$CONF_HOME/VERSION" 2>/dev/null || echo none))"
  echo "config:      CTX_DIR=$(conf CTX_DIR '(unset)') STALE_HOURS=$(conf STALE_HOURS 4) ASK_NEW_PROJECTS=$(conf ASK_NEW_PROJECTS 1)"
  echo "antigravity: $([ -f "$CONF_HOME/antigravity" ] && echo "installed (hook: $AG_HOOKS)" || echo "not installed")"
  local ctx
  ctx=$(conf CTX_DIR "")
  if [ -n "$ctx" ] && [ -f "$root/$ctx/STATE.md" ]; then echo "project:     ledger at $root/$ctx"
  elif [ -f "$root/docs/STATE.md" ] && head -n 5 "$root/docs/STATE.md" | grep -q context-kit; then echo "project:     ledger at $root/docs (legacy layout)"
  else echo "project:     no ledger in $root"; fi
}

case "${1:-}" in
  install) shift; cmd_install "$@" ;;
  init) shift; cmd_init "$@" ;;
  decline) shift; cmd_decline "$@" ;;
  sync) cmd_sync ;;
  status) shift; cmd_status "$@" ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
