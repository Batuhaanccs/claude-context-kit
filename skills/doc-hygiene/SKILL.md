---
name: doc-hygiene
description: Keep the context-kit ledger small, consistent and current. Use when the user says "clean up the docs", "dokümanları temizle", "md'ler şişti", "doc hygiene", or when STATE/LESSONS/agent/plan files exceed their line budgets or look outdated. Moves stale content to logs; never loses information.
---

# Doc hygiene

The **ledger** is the folder named in the context-kit session-start message (`<private name>/ctx/` or `docs/`), relative to
the project root (the workspace folder; not this skill's folder, not the shell's cwd).

## Budgets
| File | Limit | When exceeded |
|---|---|---|
| context-kit block in CLAUDE.md (docs layout) | ~20 lines | Trim wording; details belong in the mapped files |
| `STATE.md` | 40 lines | Past-tense lines → `logs/<work>.md` |
| `agents/<agent>.md` | 60 lines | Finished items' sections → `logs/<work>.md` |
| `journal.md` | 300 lines | Older lines → `logs/journal-<YYYY>.md` |
| `LESSONS.md` | 60 lines | Lessons no longer valid → `logs/lessons-archive.md` |
| Plan status box | 12 lines | Detail → the work's log |
| Plan file | ~150 lines | "Result" paragraphs → log; leave one line + link |
| Finished plans | n/a | Move to `plans/done/`; remove from STATE |

## Steps
1. Measure with `wc -l`; list what is over budget.
2. **Staleness sweep:** each STATE line, each agent-file section and each plan "Next": check the actual files. Done,
   abandoned or wrong → update or move to the log.
3. **Claims:** list claims older than the stale limit; ask the user before removing any. Never remove them yourself.
4. **Contradictions:** the same fact stated differently in two places → one source; the other place links to it.
5. **Tags and owners:** every shared-section line starts with `[<work name>]` or `[all]` matching an active item; every
   active item names its owner agent. Propose fixes for missing ones.
6. **Map check** (docs layout): every path in the CLAUDE.md map exists.
7. **Move, don't delete.** Leave a one-line link where content was moved. Delete only with the user's approval.
8. Show before/after line counts and the list of moves. Ask before any large move or split.

Write in the language the files already use.
