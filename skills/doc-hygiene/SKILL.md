---
name: doc-hygiene
description: Keep the project's context docs small, consistent and current. Use when the user says "clean up the docs", "dokümanları temizle", "md'ler şişti", "doc hygiene", or when STATE/LESSONS/plan files exceed their line budgets or STATE looks outdated. Moves stale content to logs; never loses information.
---

# Doc hygiene

Paths like `docs/...` are relative to the **project root**: the directory Claude Code was started in. Not this skill's directory, and not the shell's current directory after a `cd`.

## Budgets
| File | Limit | When exceeded |
|---|---|---|
| context-kit block in CLAUDE.md | ~20 lines | Trim wording; details belong in the mapped files |
| `docs/STATE.md` | 40 lines | Past-tense lines → `docs/logs/<work>.md` |
| `docs/LESSONS.md` | 60 lines | Lessons no longer valid (tool upgraded, code removed) → `docs/logs/lessons-archive.md` |
| Plan status box | 12 lines | Detail → the work's log |
| Plan file | ~150 lines | "Result" paragraphs → log; leave one line + link |
| Finished plans | n/a | Move to `docs/plans/done/`; remove from STATE |

## Steps
1. Measure with `wc -l`; list what is over budget.
2. **Staleness sweep:** for each STATE line and each plan "Next", check the actual files it refers to.
   Anything already done, abandoned or wrong is updated or moved to the log.
3. **Contradictions:** the same fact stated differently in two places (e.g. plan says "Step 5 next", STATE says
   "Step 9"). Reduce to one source; the other place links to it.
4. **Tags:** every line in STATE's shared sections starts with `[<work name>]` or `[all]`, and each tag matches an
   active item. Propose tags for untagged lines; lines of finished items move to that item's log.
5. **Map check:** every path in the CLAUDE.md map exists; every important doc is on the map.
6. **Move, don't delete.** Leave a one-line link where content was moved. Delete only with the user's approval.
7. Show the user before/after line counts and the list of moves. Ask before any large move or split.

Write in the language the docs already use.
