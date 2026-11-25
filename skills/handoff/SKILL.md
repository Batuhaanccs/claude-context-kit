---
name: handoff
description: Save this session's working state to the shared context-kit ledger so a fresh session, or another agent, can continue without loss. Use when the user says "handoff", "devret", "save state", "wrap up", "oturumu kapat", "kaydet ve bitir", "context is filling up", or before ending a long session in a project with a context-kit ledger. Updates only the ledger (and docs it maps), never code.
---

# Handoff

Goal: nothing learned in this session is lost, and the next session of **any** agent knows exactly where things stand,
who changed what, and that your claim is released.

The **ledger** is the folder named in the context-kit session-start message: `<private name>/ctx/` (e.g. `_batuhan/ctx/`)
or `docs/` (older layout), relative to the project root (the workspace folder; not this skill's folder, not the shell's cwd).
In a linked git worktree the message gives the main worktree's ledger path: use that.
**You** are the agent id from that message (e.g. `claude#a1f3`, `antigravity#ec33`); your agent file is `agents/<agent name>.md`.
No ledger → offer the context-setup skill and stop.

Write in the language the existing files use. Templates: the context-setup skill's `templates/` folder (sibling of this skill's
folder; shared copy in `~/.config/context-kit/skills/context-setup/templates/`).

## Steps
1. **Collect from this conversation** (not from files): work items touched, last finished step, anything half-done,
   decisions (with reasons), questions for the user, approaches dropped, unverified beliefs, pitfalls, files changed.
   Real time: `date "+%Y-%m-%d %H:%M"`. Git: `git rev-parse --short HEAD` and `git status --porcelain` (if a repo).
2. **Your agent file** `agents/<agent name>.md` (create from AGENT.template.md if missing). Edit only the sections of the
   items this session worked on; other sessions of the same agent may own other sections. Per item: Updated (with your
   agent id), Done, Half-done, Next (one concrete action), **Touched (not yet committed)**: every file you changed that is
   still uncommitted. Remove a section when its item is finished (copy its notes to `logs/<work>.md` first).
3. **STATE.md: re-read it from disk now** (other agents may have changed it). Edit in place:
   - Your items' lines in Active work, with the owner: `- **<work>** (<agent name>): ... Next: ...`. Never touch another item.
   - Shared sections: every line starts with `[<work name>]` or `[all]`. Refresh only your items' lines (or `[all]` lines this
     session resolved). Never remove another item's line. Pitfalls go to LESSONS, decisions to DECISIONS, not here.
   - Nothing is lost: before removing a line, append it as a dated line to `logs/<work>.md`.
   - Keep the `context-kit` marker comment at the top. Update `Updated:`.
   - `Git-base:` = the current short HEAD (git repos only), so the next session sees what changed after this point.
   - **Claims: delete your own claim lines** (your agent id). If work continues later, the next session claims again.
     Never edit another agent's claim.
4. **Journal** `journal.md`: append one line: `YYYY-MM-DD HH:MM | <agent id> | <short HEAD or -> | handoff: <one-line summary>`.
   Commits made in this session should already have their own lines; add any that are missing.
5. **Plan status box** (`plans/<work>.md`, if any): tick finished steps, update Status/Next/Blocked; mark obsolete lines.
6. **Details** (numbers, paths, commands, what was tried) → `logs/<work>.md` as dated lines.
7. **Decisions** the user made or agreed to → `DECISIONS.md` (from template if missing). A changed decision: new row, old row
   `→ superseded YYYY-MM-DD`, only with the user's agreement; otherwise list it under "Waiting on the user".
8. **Lessons**: new recurring pitfalls → one line each in `LESSONS.md` (grep first; no duplicates).
9. **Team / project docs** (outside the ledger): if one contradicts the ledger, propose the fix in your report; never edit
   them without approval.
10. **Check**: STATE <= 40 lines, agent file <= 60 lines, plan box <= 12, LESSONS <= 60. Over budget → move to `logs/`.
11. **Report in at most 5 lines**: files changed, claim released, uncommitted files left (yours / not yours), and what to type
    next time (usually "devam" / "continue", in any agent).

## Do not
- Change code, assets or configs. Commit anything (unless the user asked for a commit in this same request).
- Paste conversation transcript. Rewrite STATE.md or another agent's file from scratch.
