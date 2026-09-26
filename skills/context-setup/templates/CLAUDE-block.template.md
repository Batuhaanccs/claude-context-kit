<!-- context-kit:start (managed by the context-kit plugin; keep this block short) -->
## Project memory (context-kit)
- `docs/STATE.md` is the handoff note between sessions (auto-injected at start; if it is not in context, read it).
  It may be stale: check it against code/git before relying on it.
- Docs vs reality conflict → trust reality (code, git), tell the user, fix the doc.
- Map, read only when needed:
  - Decisions and why: `docs/DECISIONS.md` (before changing established behavior)
  - Known pitfalls: `docs/LESSONS.md` (grep the topic before using a tool/API)
  - Work plans: `docs/plans/<work>.md` (read only the status box at the top)
  - Detailed history: `docs/logs/`, `git log` (grep; never read whole)
<!-- add rows for this project's own important docs; every path here must exist -->
- One fact lives in one place; elsewhere, link to it. Write decisions as decision + reason, not recipes.
  Changing a past decision: ask the user, add a new row, mark the old one superseded.
- While working: when a plan step finishes, tick it and update the plan's status box.
- Before ending a session or when the context gets long: run the handoff skill ("handoff" / "devret").
- When summarizing or compacting, preserve: active work item, next step, pending user decisions,
  unverified assumptions, files changed.
<!-- context-kit:end -->
