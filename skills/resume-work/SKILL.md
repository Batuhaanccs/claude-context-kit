---
name: resume-work
description: Continue where the last session (of this or another agent) left off. Use at the start of a session when the user says "devam", "kaldığın yerden", "nerede kalmıştık", "continue", "pick up where we left off", "where were we", in a project with a context-kit ledger. Only when no task is in progress in this conversation: if "devam"/"continue" just means "go on" with the current task, do not use this skill. Reads the ledger, checks it against reality and other agents' claims, and confirms with the user before working.
---

# Resume work

The **ledger** is the folder named in the context-kit session-start message (`<private name>/ctx/` or `docs/`), relative to
the project root (the workspace folder; not this skill's folder, not the shell's cwd). **You** are the agent id given there.

## Steps
0. If this conversation already has a task in progress, the user means "go on": continue that task and stop here.
1. Use what the session-start message injected (STATE, your agent file, git changes, stale claims). If it is missing
   (hook did not run), read `STATE.md` and `agents/<your agent name>.md` from the ledger, and run `git log --oneline` from
   `Git-base` and `git status --porcelain` yourself. Treat all of it as a hypothesis, not ground truth.
2. Pick the work item: the one the user named; if several are active and it is ambiguous, ask which one.
   Relevant lines: tagged with that item or `[all]`. If another agent last worked on it, read that agent's file section.
3. **Claims:** is the item, or the files/resources it needs, claimed by someone else? Then say who and since when, and ask:
   wait / something else / take over. A claim older than the stale limit may be abandoned: ask before removing it.
4. Read only the **status box** of the item's plan (`plans/<work>.md`), not the whole plan or logs.
5. Reality check: do the files named exist and look as described? Commits or uncommitted changes the ledger does not
   explain (someone worked without a handoff)? Say so.
6. Reply in the user's language, at most 4 lines: Understood / Next / Conflicts or claims / Should I start?
7. After the user confirms: add your claim to STATE.md (template line format, your agent id, paths, resources), then work.
   If the user corrects something, fix the ledger right away (only that item's lines).

## Later in the session
- Before using a tool/API/library, grep `LESSONS.md` in the ledger for it. Do not read the whole file.
- Need detail? Grep `logs/` and `journal.md`. Never read them end to end.
