# context-kit

Cross-session memory for Claude Code projects. When the context fills up, the session ends, or you open a new
session for a different purpose, Claude should not **forget** what was done, **misread** it, or **act on stale
information**, and it should do this without bloating the context or turning docs into rigid recipes.

It is inactive in any project without a context-kit `docs/STATE.md` (the file must carry the `context-kit` marker
comment that setup writes, so an unrelated `docs/STATE.md` in some repo is never injected). Installing it changes
nothing until you run setup in a project.

## How it works

```
Layer 0: every session (~40 lines of STATE + a ~20-line block in CLAUDE.md)
  CLAUDE.md            rules + map: which fact lives in which file
  docs/STATE.md        handoff note: active work items, next step, open questions   (injected by hook)

Layer 1: read on demand
  docs/DECISIONS.md    date | decision | why | scope   (superseded rows are kept and marked)
  docs/LESSONS.md      [area] symptom → cause → fix    (grep, never read whole)
  docs/plans/<work>.md status box on top (<= 12 lines), then steps with "done when"

Layer 2: archive, grep only
  docs/logs/<work>.md  detailed results, numbers, what was tried
  git history
```

Principles:
- **One fact lives in one place**; other places link to it, so two files cannot contradict each other.
- **Decision + reason, not recipes.** When circumstances change, Claude can see why something was done and
  adapt, instead of following an outdated step list.
- **Docs are a hypothesis; reality wins.** Conflicts between docs and code/git are reported and fixed.
- **Start small.** Setup creates only STATE and the CLAUDE.md block. Other files appear when there is content.

### The session-start hook
`scripts/session-start.sh` runs on `startup | resume | clear | compact` and injects STATE.md with:
- **Staleness check:** project commits made after STATE.md was last updated (count + newest subjects), uncommitted or
  untracked changes, or file age when there is no git. Only the project directory counts, and `docs/` is excluded, so
  docs-only commits and other packages in a monorepo do not raise false alarms. The biggest risk for any doc-based memory is a doc nobody updated.
  This makes it visible instead of silent.
- **Guidance by source:**
  - `startup` / `clear`: STATE is a hypothesis. Confirm briefly only if the request concerns it; otherwise just help.
  - `compact`: the conversation summary is newer than STATE. Trust the summary and keep working without stopping.
  - `resume`: the conversation history is newer than STATE.
- **Budgets:** hints above 40 lines; hard cap at 150 lines with an explicit "truncated" note (never silent).
- **Safety:** silent without a marked STATE.md; ignores symlinked STATE; git checks have a 3 s per-call timeout and a
  6 s total budget, and never take the index lock; always exits 0.

### Skills
| Skill | Say | Does |
|---|---|---|
| `context-setup` | "set up context-kit" / "bağlam sistemini kur" | Inspects the project, proposes a plan, waits for approval, creates STATE + CLAUDE.md block |
| `handoff` | "handoff" / "devret" | Edits (never rewrites) STATE for the work it touched; updates the plan box, decisions, lessons and logs |
| `resume-work` | "continue" / "devam" | Reads STATE and the plan's status box, checks git, confirms in <= 4 lines before working |
| `doc-hygiene` | "doc hygiene" / "dokümanları temizle" | Budgets, staleness sweep, contradictions, map check. Moves content, never loses it |

STATE.md is an **index of active work items**, one bullet each. Parallel work streams do not overwrite each other,
and handoff re-reads the file from disk before editing, in case another session changed it.

## Install

Requires Claude Code with Git Bash on Windows (Claude Code's normal Windows setup) or any `bash` on macOS/Linux.

```bash
# Try without installing (this session only)
claude --plugin-dir /path/to/claude-context-kit

# Permanent install (this repo is its own marketplace)
claude plugin marketplace add /path/to/claude-context-kit      # or: <github-user>/claude-context-kit
claude plugin install context-kit@context-kit --scope user
```
The install is a **copy** (`~/.claude/plugins/cache/context-kit/context-kit/<version>/`). After editing this repo,
bump `version` in `.claude-plugin/plugin.json`, commit, then:
```bash
claude plugin marketplace update context-kit
claude plugin update context-kit@context-kit      # new sessions use the new version
```
To try edits before releasing them, use `claude --plugin-dir .` in a test project.

Disable / remove: `claude plugin disable context-kit@context-kit`, `claude plugin uninstall context-kit@context-kit`.
Per-project removal: delete the `context-kit:start … end` block from CLAUDE.md and the `docs/` files you no longer want.

## Everyday use
1. In a project: "bağlam sistemini kur" / "set up context-kit" (once).
2. At the start of a session: "devam" / "continue". Other requests work normally.
3. Before closing, or when the context is long: "devret" / "handoff". Do it **before** compaction, when details
   are still in context.
4. When docs feel messy or the hook warns: "doc hygiene".

## Development
- `bash tests/test-session-start.sh`: hook tests (no git, stale/fresh git, dirty tree, every source, budgets,
  Windows paths, UTF-8, garbage stdin).
- `claude plugin validate .`
- Manual check after hook changes (cannot be automated in `-p` mode): in a test project, run `/compact` in an
  interactive session, then ask Claude to quote the context-kit guidance it received. It must be the "summary is
  NEWER" line.

## Limits (honest notes)
- No plugin guarantees memory. The handoff habit is still yours; the hook makes a missed handoff **visible**.
- Handoff quality depends on what is still in context; after heavy compaction, details may already be lost.
- If `docs/` is a published docs site (MkDocs, Docusaurus, GitHub Pages), exclude the context files in the site
  config; setup warns about this.
- Project knowledge belongs in `docs/` (visible, versioned, fixable). Claude's auto memory is for personal preferences.

## Background
- Anthropic, [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents): structured note-taking outside the context, just-in-time retrieval.
- Anthropic, [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents): a progress file plus git log as the session-start anchor.
- [Cline Memory Bank](https://docs.cline.bot/best-practices/memory-bank): an active-context file separate from long-term knowledge, plus an explicit "update memory bank" ritual.

License: MIT
