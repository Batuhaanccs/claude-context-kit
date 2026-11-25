# context-kit

Cross-session and cross-agent memory for Claude Code projects, with Google Antigravity (and other agents) sharing the
same ledger. When the context fills up, the session ends, or you open a new
session for a different purpose, Claude should not **forget** what was done, **misread** it, or **act on stale
information**, and it should do this without bloating the context or turning docs into rigid recipes.

Since 0.3 several agents can work on one project, one after another or in parallel, without overwriting each other:
see [Multi-agent](#multi-agent-claude-code--antigravity).

It is inactive in any project without a context-kit ledger (`<private>/ctx/STATE.md` or `docs/STATE.md`) (the file must carry the `context-kit` marker
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
```

Principles:
- **One fact lives in one place**; other places link to it, so two files cannot contradict each other.
- **Decision + reason, not recipes.** When circumstances change, Claude can see why something was done and
  adapt, instead of following an outdated step list.
- **Docs are a hypothesis; reality wins.** Conflicts between docs and the actual files are reported and fixed.
- **Start small.** Setup creates only STATE and the CLAUDE.md block. Other files appear when there is content.

### The session-start hook
`scripts/session-start.sh` runs on `startup | resume | clear | compact` and injects STATE.md with:
- **Guidance by source:**
  - `startup` / `clear`: STATE is a hypothesis. Confirm briefly only if the request concerns it; otherwise just help.
  - `compact`: the conversation summary is newer than STATE. Trust the summary and keep working without stopping.
  - `resume`: the conversation history is newer than STATE.
- **Age:** the header shows how many days ago STATE.md was modified.
- **Budgets:** hints above 40 lines; hard cap at 150 lines with an explicit "truncated" note (never silent).
- **Safety:** silent without a marked STATE.md; ignores symlinked STATE; always exits 0. No git or other tools
  needed: it works in any folder, versioned or not.

### Skills
| Skill | Say | Does |
|---|---|---|
| `context-setup` | "set up context-kit" / "bağlam sistemini kur" | Inspects the project, proposes a plan, waits for approval, creates STATE + CLAUDE.md block |
| `handoff` | "handoff" / "devret" | Edits (never rewrites) STATE for the work it touched; updates the plan box, decisions, lessons and logs |
| `resume-work` | "continue" / "devam" | Reads STATE and the plan's status box, checks the files it names, confirms in <= 4 lines before working |
| `doc-hygiene` | "doc hygiene" / "dokümanları temizle" | Budgets, outdated-line sweep, contradictions, map check. Moves content, never loses it |

STATE.md is an **index of active work items**, one bullet each. Lines in its shared sections (questions, cautions,
assumptions, dropped attempts) are tagged `[<work name>]` or `[all]`. Parallel sessions working on different items
touch only their own lines, and handoff re-reads the file from disk before editing, in case another session changed it.

## Multi-agent (Claude Code + Antigravity)

```
<project>/_you/ctx/          private ledger: in your global git exclude, never committed, invisible to teammates
  STATE.md                   active work index + Claims (who works on what right now) + Git-base
  agents/claude.md           each agent's handoff file: done / half-done / next / Touched files, per work item
  agents/antigravity.md
  journal.md                 append-only: time | agent#session | commit | what
  DECISIONS.md LESSONS.md plans/ logs/   (created when needed)
```
- **One hook, every agent.** `scripts/session-start.sh` is Claude Code's plugin hook and, with `--agent antigravity`,
  Antigravity's global `SessionStart` hook (`~/.gemini/config/hooks.json`, JSON `injectSteps` output). Both get the
  same protocol, STATE, their own handoff file, stale claims and, in git repos, the commits and uncommitted changes since
  the last handoff, with the agent that made each commit when the journal knows it.
- **Claims** are advisory locks on paths and shared resources (`unity-editor`, `scene:X.unity`, `playmode`, ...). An agent
  that finds an overlap, or is not sure, asks the user instead of guessing. Claims older than `STALE_HOURS` are flagged;
  only the user decides to remove them.
- **Commits stay yours.** Agents stage only their own Touched files by path, add no agent names or trailers, and record
  "which agent made which commit" in the journal instead.
- **Git is optional.** Without git the ledger works the same; only the "what changed" section is missing.
- **Worktrees:** a linked git worktree reads the main worktree's ledger (the private folder is not copied by git).
- **New projects:** in a folder that looks like a project, the agent offers setup once; "no" is remembered
  (`ctx.sh decline`). `ASK_NEW_PROJECTS=0` in the config turns this off.
- Older projects with `docs/STATE.md` keep working unchanged.

### Machine setup (once)
Say "bağlam sistemini kur" / "set up context-kit" in Claude Code (the setup skill asks for your folder name), or run:
```bash
bash ~/.claude/plugins/cache/context-kit/context-kit/<version>/scripts/ctx.sh install --name _you
```
It writes `~/.config/context-kit/config` (`CTX_DIR=_you/ctx`, `STALE_HOURS=4`, `ASK_NEW_PROJECTS=1`), adds `_you/` and
`CLAUDE.local.md` to your global git exclude (`core.excludesFile`, default `~/.config/git/ignore`), copies the
agent-independent parts to `~/.config/context-kit/` (kept in sync automatically when the plugin updates), and for
Antigravity installs the hook, the four skills (`~/.gemini/config/skills/`) and a short fallback rule in
`~/.gemini/GEMINI.md`. `--no-antigravity` skips the last part. Re-running is safe.

Per project: `ctx.sh init` (private) or `ctx.sh init --docs`; `ctx.sh status` shows what is configured.

## Install

Requires Claude Code and `bash` (on Windows: Git Bash, which Claude Code's normal Windows setup already uses).

> **Status: early (0.x).** Tested on Windows 11 with Claude Code 2.1. macOS and Linux are not tested yet; the hook
> avoids GNU-only tools where possible, but please report problems.

From GitHub (this repo is its own marketplace), in a terminal:
```bash
claude plugin marketplace add Batuhaanccs/claude-context-kit
claude plugin install context-kit@context-kit --scope user
```
or inside a Claude Code session: `/plugin marketplace add Batuhaanccs/claude-context-kit`, then
`/plugin install context-kit@context-kit`. Start a new session afterwards.

Get updates: `claude plugin marketplace update context-kit` then `claude plugin update context-kit@context-kit`.

From a local clone (for development): `claude plugin marketplace add /path/to/claude-context-kit`, same install
command. The install is a **copy** (`~/.claude/plugins/cache/context-kit/`), so local edits need a version bump and the
two update commands above. To try edits without installing: `claude --plugin-dir /path/to/claude-context-kit`.

Disable / remove: `claude plugin disable context-kit@context-kit`, `claude plugin uninstall context-kit@context-kit`.
Per-project removal: delete the `context-kit:start … end` block from CLAUDE.md and the `docs/` files you no longer want.

## Everyday use
1. In a project: "bağlam sistemini kur" / "set up context-kit" (once).
2. At the start of a session: "devam" / "continue". Other requests work normally.
3. Before closing, or when the context is long: "devret" / "handoff". Do it **before** compaction, when details
   are still in context.
4. When docs feel messy or the hook warns: "doc hygiene".

## Development
- `bash tests/test-session-start.sh`: hook and `ctx.sh` tests (activation, marker, every source, budgets, age,
  Windows paths, UTF-8, garbage stdin, install/init/decline, private ledger, claims, journal, Antigravity JSON,
  worktrees). They use temp homes and never touch your real config.
- `claude plugin validate .`
- Manual check after hook changes (cannot be automated in `-p` mode): in a test project, run `/compact` in an
  interactive session, then ask Claude to quote the context-kit guidance it received. It must be the "summary is
  NEWER" line.

## Limits (honest notes)
- Claims are a convention, not an OS lock: they work as long as agents follow the protocol. Claude gets it from the
  hook every session; in Antigravity the hook does the same, and the GEMINI.md rule is a fallback.
- No plugin guarantees memory. The handoff habit is still yours. If a handoff is missed, STATE is outdated: the note
  shows how many days ago STATE was modified, and Claude checks it against the actual files before relying on it.
- Handoff quality depends on what is still in context; after heavy compaction, details may already be lost.
- If `docs/` is a published docs site (MkDocs, Docusaurus, GitHub Pages), exclude the context files in the site
  config; setup warns about this.
- Project knowledge belongs in `docs/` (visible, versioned, fixable). Claude's auto memory is for personal preferences.

## Background
- Anthropic, [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents): structured note-taking outside the context, just-in-time retrieval.
- Anthropic, [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents): a progress file read at every session start.
- [Cline Memory Bank](https://docs.cline.bot/best-practices/memory-bank): an active-context file separate from long-term knowledge, plus an explicit "update memory bank" ritual.

License: MIT
