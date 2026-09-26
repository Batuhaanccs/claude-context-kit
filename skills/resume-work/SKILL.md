---
name: resume-work
description: Continue where the last session left off. Use at the start of a session when the user says "devam", "kaldığın yerden", "nerede kalmıştık", "continue", "pick up where we left off", "where were we", in a project that has docs/STATE.md. Only when no task is in progress in this conversation: if "devam"/"continue" just means "go on" with the current task, do not use this skill. Reads the handoff note, checks it against reality, and confirms with the user before working.
---

# Resume work

Paths like `docs/...` are relative to the **project root**: the directory Claude Code was started in. Not this skill's directory, and not the shell's current directory after a `cd`.

## Steps
0. If this conversation already has a task in progress, the user means "go on": continue that task and stop here.
1. Use `docs/STATE.md` as injected at session start (read it only if it is not already in context).
   Treat it as a hypothesis written by an earlier session, not as ground truth.
2. Pick the work item: the one the user named; if several are active and it is ambiguous, ask which one.
3. Read **only the status box** at the top of that item's plan file. Not the whole plan, not the logs.
4. Cheap reality check:
   - If the session-start note reported commits or changes after STATE's last update, look at them
     (`git log --oneline` for that range, `git status --short`) and reconcile with STATE.
   - Do files and branches named in STATE exist? Does "Next" still make sense given the latest commits?
5. Reply in the user's language, in at most 4 lines:
   - Understood: <work item, where it stands>
   - Next: <step>
   - Waiting on you / conflicts found: <if any>
   - Should I start?
6. Do not start work before the user confirms. If the user corrects something, fix STATE.md right away
   (only that item's lines).

## Later in the session
- Before using a tool/API/library, grep `docs/LESSONS.md` for it. Do not read the whole file.
- Need detail? Grep `docs/logs/` or `git log`. Never read a log end to end.
