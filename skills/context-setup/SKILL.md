---
name: context-setup
description: Set up the shared cross-session, cross-agent context system (context-kit) in a project, or on this machine for the first time. Use when the user says "set up context-kit", "bağlam sistemini kur", "context kit kur", "create STATE.md", "bu projeyi context-kit'e geçir", or answers yes when the session-start message offers setup. Inspects first, proposes a plan, and changes nothing without approval. Never overwrites existing files.
---

# Context setup

Works the same in every agent (Claude Code, Antigravity, ...). "Project root" = the workspace folder the session was
started in. Not this skill's directory, and not the shell's current directory after a `cd`.

**Control script** `ctx.sh`: the shared copy is `~/.config/context-kit/scripts/ctx.sh`. If it does not exist yet, use the
plugin's copy: `scripts/ctx.sh` two levels above this skill's folder (in Claude Code: `${CLAUDE_SKILL_DIR}/../../scripts/ctx.sh`).
Run it with `bash`. Templates: `templates/` in this skill's folder.

## 0. Machine setup (once per computer)
If `~/.config/context-kit/config` does not exist:
- Ask the user for their private folder name (suggest `_<first name>`, e.g. `_batuhan`) and whether they use Antigravity.
- Explain in 2 lines what install does: writes the config, adds `<name>/` and `CLAUDE.local.md` to the **user's global
  git exclude** (these never get committed in any repo on this machine; teammates are not affected), copies the kit to
  `~/.config/context-kit/`, and (Antigravity) installs its SessionStart hook, skills and a fallback rule in `~/.gemini/`.
- After approval: `bash <ctx.sh> install --name <name>` (add `--no-antigravity` if not used). Show its output.

## 1. Inspect the project (read-only)
- Look for: CLAUDE.md / CLAUDE.local.md / AGENTS.md / GEMINI.md, `docs/` or `Docs/`, README, ROADMAP/TODO, plan files,
  the user's private folder (e.g. `_batuhan/`), other memory systems (`memory-bank/`, `.cursorrules`, `.clinerules`).
- Team or solo? Signs of a team repo: a remote, several authors (`git shortlog -sn --all | head`), shared docs written by others.
- Already set up? (`bash <ctx.sh> status`): then this is a re-run; only report gaps.
- A `STATE.md` without the `context-kit` marker belongs to something else: never touch it.

## 2. Propose, then wait for approval
Recommend a layout and show a short table of what will be created:
- **private** (default, recommended): ledger in `<name>/ctx/`, invisible to git. Right for team repos and whenever the
  notes concern only the user's own agents. Tracked files (CLAUDE.md, AGENTS.md, team docs) are **not** edited.
- **docs**: ledger in `docs/`, versioned with the project. Only for solo projects where the user wants that.
Ask: anything that must not be touched?

## 3. Create
- `bash <ctx.sh> init` (or `init --docs`) in the project root. It creates `STATE.md`, `journal.md`, `agents/` and,
  in a git repo, verifies the private ledger is ignored. It never overwrites.
- Fill `STATE.md` with the **real current state** (from this conversation and the project's files): active work items
  with owner, tagged shared-section lines (`[<work name>]` or `[all]`). If there is no active work, keep the one line.
  Get the time with `date "+%Y-%m-%d %H:%M"`.
- **docs layout only:** append the CLAUDE-block template to CLAUDE.md (between its markers), adding map rows only for files
  that exist. Back up an existing file first (`<file>.bak-YYYYMMDD`) unless the project uses version control.
- Do **not** create DECISIONS, LESSONS, plans or logs yet; handoff creates them from the templates when needed.

## 4. Existing notes (only with approval)
- Existing personal notes (e.g. `_batuhan/notlar/02-durum.md`): do not move them. Offer to link them from STATE
  ("Watch out" or the item line) so agents know they exist.
- Docs-layout migration of scattered decisions or oversized plans: as before; leave a link in the old place.
- Project knowledge found in an agent's own memory → suggest moving it to the ledger. Personal preferences stay there.

## 5. Verify and report (at most 8 lines)
- STATE <= 40 lines; private ledger not visible in `git status`; every mapped path exists.
- Tell the user the words that matter, in every agent: "devret" / "handoff" at the end of a session, "devam" / "continue"
  at the start, "doc hygiene" when things get messy.

## Do not
- Touch code, assets or configs. In the private layout, do not edit any tracked file.
- Split, move or delete files without approval.
