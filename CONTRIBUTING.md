# Contributing and git workflow

Adapted from a team Git/GitHub standard (Conventional Commits, short-lived branches, protected `main`),
simplified for a small plugin repo.

## `main` is always releasable
Every commit on `main` must pass:
```bash
bash tests/test-session-start.sh
claude plugin validate .
```
No direct commits to `main`; work happens on a branch and is merged through a pull request.

## Branches
Format `<type>/<short-description>`: lowercase, words joined with `-`, no spaces, no non-ASCII characters,
no personal names. One task per branch; delete it after merging.
```
feat/work-item-tags     fix/hook-trailing-newline     docs/readme-install
refactor/hook-output    chore/repo-setup              test/hook-budgets
```

## Commits: Conventional Commits, in English
`<type>(<scope>): <description>`, optionally followed by a blank line and a body explaining *why*.

| Type | Use for |
|---|---|
| `feat` | new behavior (new skill step, new hook output) |
| `fix` | bug fix |
| `refactor` | same behavior, better structure |
| `perf` | faster / fewer tokens |
| `docs` | README, CONTRIBUTING, comments only |
| `test` | tests only |
| `chore` | repo maintenance, version bumps, config |
| `revert` | undo an earlier commit |

Scopes: `hook`, `setup`, `handoff`, `resume`, `hygiene`, `templates`, `tests`, `manifest`, `release`, `repo`.

Good: `fix(hook): keep last line when STATE has no trailing newline`
Bad: `update`, `fix`, `changes`, `wip`, `final2`

**Atomic commits:** one logical change per commit. A hook fix, a template change and a README update are three commits.

## Pull requests
Title in the same Conventional Commits format. Small: one feature or fix per PR. Merge with rebase to keep the
atomic commits and a linear history:
```bash
git switch main && git pull origin main
git switch -c fix/some-bug
# ... commits ...
git push -u origin fix/some-bug
gh pr create --fill
gh pr merge --rebase --delete-branch
```

## Releases (every change that users should get)
1. On the branch, bump `version` in `.claude-plugin/plugin.json` (semver: `fix` → patch, `feat` → minor) in its own
   commit: `chore(release): v0.3.0`.
2. After merging: `git switch main && git pull && git tag v0.3.0 && git push origin v0.3.0`.
3. Update the local install:
   ```bash
   claude plugin marketplace update context-kit
   claude plugin update context-kit@context-kit
   ```

## Not committed
`docs/` is the maintainer's own context-kit working notes (STATE, logs). It is git-ignored so it never ships with
the plugin or appears on GitHub.
