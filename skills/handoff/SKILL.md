---
name: handoff
description: Save the session's working state to the project's docs so a fresh session can continue without loss. Use when the user says "handoff", "devret", "save state", "wrap up", "oturumu kapat", "kaydet ve bitir", "context is filling up", or before ending a long session in a project that has docs/STATE.md. Updates only docs, never code.
---

# Handoff

Goal: nothing learned in this session is lost when the context is compacted or closed. A new session that reads
only CLAUDE.md + `docs/STATE.md` must be able to continue from the right place, without being misled by stale lines.

Paths like `docs/...` are relative to the **project root**: the directory Claude Code was started in. Not this skill's directory, and not the shell's current directory after a `cd`.

Write in the language the existing docs use (for new files: the language the user speaks).
If `docs/STATE.md` does not exist, offer the `context-setup` skill instead and stop.

## Steps
1. **Collect from this conversation** (not from files): which work items this session touched, the last finished
   step, anything half-done, decisions made (with reasons), pending questions for the user, approaches tried and
   dropped, beliefs not yet verified, recurring pitfalls discovered. Run `git status --short` if it is a git repo.
   Get the real time with `date "+%Y-%m-%d %H:%M"`; never guess it.
2. **Re-read `docs/STATE.md` from disk now** (another session may have changed it since it was injected).
   Edit it in place:
   - Update or add only the bullets of the work this session touched. Keep other work items untouched.
     Remove an item only when it is finished (and its plan box says so) or the user dropped it.
   - Nothing is lost: before removing any line (a finished item, an obsolete note, a "tried and dropped" entry),
     append it as a dated line to `docs/logs/<work>.md`.
   - Keep the `context-kit` marker comment at the top; the session-start hook injects only files that have it.
   - "Next" is one concrete action someone could start immediately ("run the X tests after fixing Y", not "continue").
   - Refresh "Waiting on the user", "Watch out", "Unverified assumptions", "Tried and dropped" for your items;
     delete lines that are no longer true. Anything recorded in LESSONS or DECISIONS (steps 5-6) is not repeated
     in STATE; a fixed pitfall is a lesson, not a "watch out".
   - Update the `Updated:` line.
3. **Plan status box** (`docs/plans/<work>.md`, if the work has one): tick finished steps, update Status/Next/Blocked.
   Mark instructions that are no longer valid as `(obsolete)` or remove them. Never leave an old "next step" standing.
4. **Details** (numbers, file paths, commands, what was tried) go to `docs/logs/<work>.md` as dated lines. Not into
   the plan, not into STATE.
5. **Decisions** the user made or agreed to in this session: add rows to `docs/DECISIONS.md` (create it from the
   template if missing). A changed decision gets a new row and the old row is marked `→ superseded YYYY-MM-DD`,
   but only if the user agreed to the change; otherwise list it under "Waiting on the user".
6. **Lessons**: new recurring pitfalls → one line each in `docs/LESSONS.md` (create from template if missing).
   Grep first; do not duplicate.
7. **Other tracking docs** listed in the CLAUDE.md map (roadmap, TODO): if one contradicts STATE, propose the fix
   in your report; do not edit them without the user's approval.
8. **Check**: STATE <= 40 lines, plan box <= 12 lines, LESSONS <= 60 lines. Over budget → move the excess to
   `docs/logs/` (suggest `doc-hygiene` if it is large). Re-read STATE once: does every line describe the present?
   Does anything contradict a plan box?
9. **Report in at most 5 lines**: which files changed, and what to type in the next session (usually just
   "devam" / "continue"). If the repo is git, offer to commit the docs; do not commit unasked.

Templates: `${CLAUDE_SKILL_DIR}/../context-setup/templates/`.

## Do not
- Change code, assets or configs. This skill only edits docs.
- Paste conversation transcript. Write state and decisions, not dialogue.
- Rewrite STATE.md from scratch; other work items may live there.
