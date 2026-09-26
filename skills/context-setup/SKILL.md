---
name: context-setup
description: Set up the cross-session context system (context-kit) in a project, or migrate an existing project to it. Use when the user says "set up context-kit", "bağlam sistemini kur", "context kit kur", "create STATE.md", "bu projeyi context-kit'e geçir". Inspects first, proposes a plan, and changes nothing without approval. Never overwrites existing files.
---

# Context setup

Paths like `docs/...` are relative to the **project root** (the current working directory), never to this skill's directory.

Templates live in `${CLAUDE_SKILL_DIR}/templates/`: STATE, PLAN, LESSONS, DECISIONS, CLAUDE-block.
Doc content is written in the user's language; template headings may be translated to match.

## 1. Inspect (read-only)
- Look for: CLAUDE.md (root and `.claude/`), AGENTS.md, `docs/`, README, ROADMAP/TODO, plan files,
  other memory systems (`memory-bank/`, `.cursorrules`, `.clinerules`), git status.
- Measure sizes (`wc -l`). Note what is missing, oversized, duplicated or stale
  (e.g. a "next step" that is already done).
- If `docs/STATE.md` or a `context-kit:start` block already exists, this is a re-run: only report gaps.

## 2. Propose, then wait for approval
Show a short table: what exists, what you will create, what you suggest moving. Ask two questions:
- Should the context docs be committed to git? (Default: yes. The staleness warning relies on git history.)
  If no, add `docs/STATE.md docs/logs/` (or what the user chooses) to `.gitignore`.
- Anything that must not be touched?

## 3. Create (only what is missing; start small)
- `docs/STATE.md` from the template, filled with the **real current state** (from this conversation, git log,
  plan files). If there is no active work, say so in one line. Use `date "+%Y-%m-%d %H:%M"` for the time.
- CLAUDE.md: append the CLAUDE-block template (between its `context-kit:start/end` markers). Do not delete or
  rewrite existing rules. Add map rows for the project's own important docs; remove rows for files that do not exist.
  If CLAUDE.md does not exist, create it with a one-line project description plus the block.
- Do **not** create LESSONS, DECISIONS, plans or logs yet unless there is real content for them now.
  They are created from the templates the first time something needs to go there (handoff does this).
- If the project is not a git repo, back up any file you change first (`<file>.bak-YYYYMMDD`).

## 4. Migrate existing material (only with approval)
- Scattered decisions (in roadmap, plans, README) → rows in `docs/DECISIONS.md`; leave a link in the old place.
- Oversized plan files → add the status box on top; move long "result" paragraphs to `docs/logs/<work>.md`,
  leaving one line + link. Mark obsolete instructions `(obsolete)`.
- Project knowledge found in Claude's auto memory → suggest moving it to docs (visible, versioned, fixable).
  Personal preferences stay in auto memory.

## 5. Verify and report
- STATE <= 40 lines; every path on the map exists; no fact is stated in two places.
- Show before/after line counts and the list of changes, in at most 8 lines.
- Tell the user the three words that matter: "handoff" / "devret" at the end of a session, "continue" / "devam" at
  the start, "doc hygiene" when things get messy.

## Do not
- Touch code, assets or configs.
- Split, move or delete files without approval.
- Put project knowledge into auto memory.
