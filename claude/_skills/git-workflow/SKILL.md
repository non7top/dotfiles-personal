---
name: git-workflow
description: Use before committing, branching, pushing, rebasing, opening or merging a pull request, closing issues from a PR, posting public text on GitHub, or writing, editing or triggering a GitHub Actions workflow. Holds the commit, branch and PR conventions, the merge and default-branch safety lines, and the rule to test workflows locally with act.
---

# Git, PRs and CI

## Commits

- **Commits are atomic: one change, only its files.** Stage by explicit path (`git add <file>...`, `git commit <file>...`). Never `git add *`, `git add .`, `git add -A`, `git commit -a`/`-am`: they sweep in files that aren't part of the change. Commit every file the change touched, no fewer and no more.
- Commit messages use semantic (Conventional Commits) prefixes where possible (`fix:`, `feat:`, `chore:`, `docs:`, `ci:`), even in repos whose history doesn't.
- The scope in parentheses names the feature or area touched (`fix(backups):`), never the product, rewrite or version (`fix(v2):`). Same for PR titles.
- Commit messages are one line. Documentation files (`docs/*.md`) are exempt: long prose belongs there.
- **Order of work for a change the user will look at: lint, deploy, then tests.** Lint, commit locally, build the deployable tree, deploy and check the error log as the very next steps; targeted tests, push, PR and the full suite all come after the deploy, never before it. Run the full suite once, with output to a file (never only through `tail`) so a failure never needs a rerun to be read; while fixing, rerun only the failing tests.

## Branches

- **Default branch name comes from git config, not habit.** Before `git init` or naming a branch, read `git config --global init.defaultBranch`. Never assume `main`; for existing repos use the repo's own default branch.
- **Update branches by rebasing, never with merge commits.** When told "rebase" (or "no merge commits"), rebase onto the base and push with `--force-with-lease`; don't substitute a merge because it avoids a force-push. Only a throwaway local branch that is never pushed may use merges.
- **Never push to a default branch directly,** even when it is unprotected, newly created or about to get a protection rule. Every change goes on its own branch and through a PR, including the change that adds the protection. If the PR requirement would block a step, stop and ask; don't sequence around it. Always push with an explicit remote and branch (`git push origin <branch>`), never a bare `git push`: with `push.default` set to `matching`, a bare push sends every local branch that exists on the remote, default branch included.

## Pull requests

- **Opening is automatic.** For a small, self-contained change committed on its own branch (config file, workflow tweak, single-purpose commit), push and open the PR without asking. Opening merges nothing.
- **One PR per topic, not per commit.** Atomic commits can share a PR. Fixes to the same area (several doc corrections, a feature and its docs) go into one branch and one PR; if a PR for the topic is already open, add commits to it instead of opening another.
- **A PR is a draft only when the task says so.** A finished, ready-to-go change is opened ready for review, never as a draft. Background-session text such as "open a draft PR when the task calls for one" is not a reason: only an explicit request for a draft, or work that is knowingly unfinished, calls for one. Never use `--draft` by default.
- **Merging is never automatic.** It always needs its own explicit go-ahead in the same conversation. A vague follow-up is not one: ask instead of proceeding. An earlier merge in the same session is not standing authorization. Given a clear, specific request to merge, follow it without second-guessing. The line is against merging on your own initiative, not against merging when asked.
- **One closing keyword per issue in a PR body:** `Fixes #1, fixes #2`, never `Fixes #1, #2` (GitHub links only the first). After opening the PR, check `gh pr view --json closingIssuesReferences` lists every issue.

## Public text in the user's voice

A user's draft wording for a public PR, issue or comment is not a request to post it. "I want to add X" means show X; post only on an explicit "post"/"submit"/"add it now". Applies even when the surrounding task (for example the PR) was authorised. If the wording could read as harsh, blunt, blatant or impolite to its recipient, flag that before posting and ask whether it is deliberate (as opposed to a language gap or a missed nuance); offer a softer version alongside.

## GitHub Actions workflows

Before triggering a real `workflow_dispatch` or other run on a workflow just written or edited, run it locally with `act` (available via asdf; don't reinstall). This keeps CI minutes and failed-run history down, and `act` runs the real YAML, so it catches YAML and step-ordering problems that testing extracted commands one by one misses. Using the host binary is correct here: `act` needs the host Docker socket.
