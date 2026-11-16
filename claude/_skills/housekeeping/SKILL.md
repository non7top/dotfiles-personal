---
name: housekeeping
description: Survey a repo for unfinished work and propose how to land it. Compares the working tree, local branches, stashes and worktrees against the remote and open PRs, groups loose work into atomic changes, and suggests a PR plan. Read-only; it never commits, pushes or deletes. Use when asked for housekeeping, "what's left undone", "clean up this repo", "what is unpushed", or at the start of a session in a messy checkout.
---

# Housekeeping

Output is a report and a proposed plan. Nothing is committed, pushed, merged, deleted, stashed or popped until the user approves a specific step.

## 1. Survey

Run the helper. It is read-only apart from `git fetch --all --prune` (remote-tracking refs only), so remote state is fresh in the same turn:

```
~/.claude/skills/housekeeping/survey.sh
```

Pass a path as the one argument to survey another repo. Save the output to the scratchpad and read it whole; do not pipe it through `head` or `tail`.

It covers: in-progress rebase/merge/cherry-pick, working tree and diffstat, every local branch (vs upstream, vs default, merged state), unmerged remote-only branches, stashes (with stat and untracked contents), worktrees (dirty, missing, prunable), commits on no remote, WIP-style commit subjects, open PRs with checks, the PR state of each local branch, untracked files.

## 2. Verify what the survey cannot decide

Run a targeted read for each of these before stating it as fact:

- **Merged?** `merged=yes(...)` in the survey is git ancestry or patch equivalence only. A squash-merged branch shows `no`. The PR section is authoritative: a MERGED PR means the branch is done, even when ancestry says `no`. A branch with `no-up`/`GONE` upstream and no PR is the interesting case.
- **Branch with `no` merge and no PR:** read `git log <base>..<branch>` and the diff before calling it unfinished or abandoned.
- **Each stash:** `git stash show -p stash@{N}` against current default. Say whether its content is already in default (superseded), partly in, or unique. A stash message such as "superseded by PR #42" is a claim; check it.
- **Each dirty worktree and the current tree:** read the diff. Say which hunks belong together.
- **Stacked PRs** (head of one is the base of another): list the chain bottom to top and which link is blocking (`DIRTY` = conflicts, `BEHIND` = needs rebase, failing checks).
- **Branches whose upstream is gone:** confirm the PR merged or closed before proposing deletion; `GONE` alone only means the remote branch was removed.

Skip nothing because "it looks stale". Dates are evidence of age, not of being finished.

## 3. Classify

Put every item in exactly one bucket:

- **Landed**: content is in default (merged PR, ancestry, or verified patch equivalence). Safe to delete branch/worktree after confirming nothing uncommitted lives in it.
- **In flight**: open PR. Record state and blocker.
- **Unpublished**: commits on no remote, or a branch with no PR. Needs a push and PR, or a decision to drop.
- **Loose**: uncommitted changes, untracked files, stash content not in default. Needs grouping (step 4).
- **Dead**: superseded or abandoned, with the evidence. Needs the user's call.
- **Blocked**: in-progress rebase/merge, conflicting PR, missing worktree dir.

## 4. Group loose work atomically

For uncommitted changes, stashes and unpublished branches that mix concerns:

- One change = one purpose, only the files (or hunks) that serve it. Name each group by what it does, in Conventional Commits form (`fix(scope): ...`) where scope is the feature or area, never the product or version.
- A file with hunks for two purposes is split with `git add -p`; flag it, do not hide it in one group.
- Generated or incidental churn (lockfile reorder, tool-version bumps from a local install) is its own group or is dropped, never bundled with a feature.
- Order groups so each stands on the previous one only when it must (shared file, dependency). Independent groups become independent PRs off the default branch.
- Secrets, tokens, private hostnames, device identifiers found in a group: flag it. If the repo is public (the survey prints visibility), they must not be committed.

## 5. Report

Lead with the headline: how many things need action and the single most urgent one. Then:

1. **Needs attention**, ranked: blocked, then unpublished work at risk of loss (stashes, local-only commits, dirty worktrees), then loose changes.
2. **In flight**: PR table (number, head -> base, blocker). Collapse stacks into one line each.
3. **Safe to clean**: landed branches, GONE-upstream branches with merged PRs, prunable worktrees, superseded stashes. Give the exact command per item but do not run it.
4. **Proposed PR plan**: per group, a branch name, a one-line commit message, the files, whether it stacks on another, and the base. Say which require rebasing an existing PR.
5. **Unverified**: only what needs a running system or credentials; say which.

Plain ASCII, short rows, no narration of what the survey did.

## 6. Act only on approval

When the user picks steps, follow their global rules:

- Stage by explicit path, never `git add -A`, `.` or `commit -a`.
- Each group on its own branch; never push to the default branch.
- Update branches by rebase and `--force-with-lease`, never merge commits.
- Open ready PRs, not drafts, unless the work is knowingly unfinished.
- One closing keyword per issue in the PR body.
- Merging needs its own explicit go-ahead.
- Before dropping a stash or deleting a branch, show its tip sha so it can be recovered.
- Removing a worktree: check it is clean first, and stop any compose stack it started.

## Gotchas

- Do not run the survey and then answer from memory a day later; remote state goes stale. Re-run.
- `git worktree list` only knows registered worktrees. A worktree directory deleted by hand shows as prunable; one moved by hand shows as missing.
- Branch names reused for a new PR after an earlier merge make `gh pr list --head` return both; read the dates.
- The default branch is read from `origin/HEAD`, falling back to master/main/trunk/develop. If the survey prints the wrong one, rerun comparisons by hand against the right base.
