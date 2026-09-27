# context-kit: Claude Code plugin (cross-session memory)

Source of the `context-kit` plugin; the repo is also its own marketplace. What it does and why: `README.md`.

## Rules for working on this repo
- The plugin is installed at user scope and used in all of the user's projects. A bug here affects all their work:
  change carefully, test before every release.
- Git workflow (branches, Conventional Commits, PRs, releases): `CONTRIBUTING.md`. Push after every update.
- Plugin internals (skills, hook, templates, README) are in English; talk to the user in Turkish.
- The plugin must not depend on git or any other tool in user projects; it must work in any folder.
- Installed copy lives in `~/.claude/plugins/cache/context-kit/`; edits here reach it only after a release.
- `/compact` cannot be tested in `claude -p`; test it in an interactive session.

<!-- context-kit:start (managed by the context-kit plugin; keep this block short) -->
## Project memory (context-kit)
- `docs/STATE.md` is the handoff note between sessions (auto-injected at start; if it is not in context, read it).
  It may be outdated: check it against the actual files before relying on it.
- Docs vs reality conflict → trust the actual files, tell the user, fix the doc.
- Map, read only when needed:
  - Decisions and why: `docs/DECISIONS.md` (before changing established behavior)
  - Known pitfalls: `docs/LESSONS.md` (grep the topic before using a tool/API)
  - Detailed history: `docs/logs/` (grep; never read whole)
- One fact lives in one place; elsewhere, link to it. Write decisions as decision + reason, not recipes.
  Changing a past decision: ask the user, add a new row, mark the old one superseded.
- Before ending a session or when the context gets long: run the handoff skill ("handoff" / "devret").
- When summarizing or compacting, preserve: active work item, next step, pending user decisions,
  unverified assumptions, files changed.
<!-- context-kit:end -->
