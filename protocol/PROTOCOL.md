## Multi-agent protocol (context-kit)
Several agents (Claude Code, Antigravity, others) and parallel sessions of each may work on this project.
You are `{{AGENT}}`. The shared ledger is `{{LEDGER}}/` (private notes; never commit it, never copy its content into tracked files).
- `STATE.md`: active work index + **Claims** (who is working on what right now). Re-read it from disk before editing; edit only your own lines.
- `agents/<agent>.md`: each agent's handoff file (one section per work item). Yours: `agents/{{AGENT_NAME}}.md`.
- `journal.md`: append-only, one line per commit or handoff: `YYYY-MM-DD HH:MM | <agent#tag> | <commit or -> | <what>`.

**Before starting a task that changes files or uses a shared resource:**
1. Read the Claims section. A claim covers its paths (folders include everything under them) and resources
   (`unity-editor`, `scene:<file>`, `playmode`, `build`, `dev-server:<port>`, ...).
2. Overlap, or you are not sure whether it overlaps → do not start; tell the user who holds it since when and ask:
   wait / do something else / take over. Never decide "it probably does not touch mine" on your own.
3. A claim older than the stale limit ({{STALE_HOURS}} h) may be abandoned: ask the user before removing it. Never remove another agent's claim yourself.
4. Add your claim (use the exact format of the template line in STATE.md), then start.
   Driving the Unity Editor (MCP, opening scenes, Play mode, tests in the Editor) needs the `unity-editor` resource, exclusively.
   Scenes, prefabs and other hard-to-merge files belong to one claim at a time.
Read-only work (answering questions, reading code) needs no claim.

**While working:** list every file you change under your work item in your agent file ("Touched").
**Committing:** stage only files on your Touched list, by explicit path (never `git add -A` / `git add .`).
Changed files that are not yours: leave them out and tell the user. Commits carry no agent name or AI trailer.
After a commit, append a journal line with the short hash.
**Finishing / handing off** (handoff skill, "devret"): update your agent file and your STATE lines, set `Git-base:` to the
current `git rev-parse --short HEAD` (if git), append a journal line, then delete your claim.
**Changes you did not expect** (git commits or files not explained by the ledger): ask the user what happened before relying on them.
