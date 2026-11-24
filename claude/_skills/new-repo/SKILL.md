---
name: new-repo
description: Use when creating a new GitHub repository, bringing an existing one up to the standard setup, or auditing repos for gaps. Covers repo settings with gh-repo-config, Dependabot, release-please with the forecast preview, conventional commits, pre-commit, workflow lint, LICENSE and SECURITY.md, and keeping tokens out of remote URLs.
---

# New repository setup

The standard every repo is measured against. `check.sh` lists what a repo is missing:

```
~/.claude/skills/new-repo/check.sh [repo-path...]
```

It is read-only, defaults to the current directory, and exits 1 if there is a gap. Do the steps below in order; each one is a separate commit.

## 1. Decide, then create

- Visibility. A private repo on a free plan gets no rulesets or branch protection (gh-repo-config skips them) and a monthly Actions quota (`gh ab` shows the budget).
- Default branch: `git config --global init.defaultBranch`, not habit.
- Merge strategy: real merge commits. release-please reads every commit that lands, and the forecast models the merge commit GitHub creates.
- `gh repo create <owner>/<name> --public|--private --source . --remote origin`. The remote URL is `git@github.com:...` or plain `https://github.com/...`. Never put a token in it: git stores the URL in `.git/config` in clear text. `check.sh` flags it without printing the value; rotate the token and run `git remote set-url`.

## 2. Baseline files

- `LICENSE`, `README.md`, `SECURITY.md` (report privately through GitHub's "Report a vulnerability"; which versions get fixes), `.gitignore`.
- A `Makefile` as the entry point for build, test and lint, running in containers (see the `docker` skill).
- `.pre-commit-config.yaml`: `pre-commit-hooks` (trailing-whitespace, end-of-file-fixer, check-yaml, check-json, check-added-large-files, check-merge-conflict, mixed-line-ending) and `conventional-pre-commit` at the `commit-msg` stage.
- `.github/workflows/pre-commit.yml`: runs the same config in CI on pull requests and pushes to the default branch.

## 3. Repo settings: gh-repo-config

```
gh extension install non7top/gh-repo-config
gh repo-config init            # writes .github/repo-config.json with the built-in defaults
gh repo-config push --dry-run  # diff against the live settings
gh repo-config push
```

Later, `pull` captures drift from the live repo and `sync` also deletes labels, rulesets and protection the file does not list (it asks first). A dry run that prints "No changes" is the drift check.

What the file must set:
- Merge commits allowed, with `merge_commit_title: MERGE_MESSAGE` and `merge_commit_message: PR_TITLE`, so the PR title lands in the merge commit body where release-please and the forecast read it.
- `security_and_analysis`: secret scanning with push protection, Dependabot security updates.
- A ruleset on the default branch: pull request required, no deletion, no force push (public repos or a paid plan).
- Labels `autorelease: pending`, `autorelease: tagged`, `RELEASE` and `RELEASE PENDING`; copy the rest from a repo that already has the file (`gh repo-config pull` there).

## 4. Dependabot

`.github/dependabot.yml`, one entry per ecosystem the repo uses, always including `github-actions` and, with a Dockerfile, `docker`:

```
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    commit-message:
      prefix: deps
    groups:
      github-actions:
        patterns: ["*"]
```

- The `deps` prefix needs a matching `deps` section in the release-please `changelog-sections`, or those commits never show up in a changelog.
- Missing ecosystems: `check.sh` compares the tracked files with the config. `non7top/dependabot-mia` does the same as a scheduled action and can open the issue or PR.
- A pinned or ignored dependency gets a comment saying why.
- The weekly batch of Dependabot PRs is stacked with the `dependabot-stack` skill.

## 5. Releases: release-please and the forecast

Files in the repo root:
- `release-please-config.json`: `packages` with `"."`, a `release-type` for the language (`simple` when nothing fits), `bump-minor-pre-major: true`, `changelog-sections` for feat, fix, perf, revert and deps, and `extra-files` for a version stored elsewhere.
- `.release-please-manifest.json`: `{".": "<last released version>"}`, or `0.0.0` before the first release.

Workflows, calling the shared ones in `non7top/gh-workflows` (pin `@main`; it has no tags):
- `release-please.yml` on push to the default branch: `uses: non7top/gh-workflows/.github/workflows/release-please.yml@main` with `contents: write` and `pull-requests: write`.
- `release-please-preview.yml` on `pull_request` (types `opened`, `synchronize`, `reopened`, `edited`) with a concurrency group per PR number: `uses: non7top/gh-workflows/.github/workflows/release-please-preview.yml@main`. It runs `non7top/release-please-forecast@v1` and colors the `RELEASE` label by the predicted bump before the merge. Without the reusable workflow, call the action directly after a checkout with `fetch-depth: 0`.
- `release.yml` builds and publishes (`workflow_call` with `tag` and `publish` inputs, plus `workflow_dispatch`). A tag made with `GITHUB_TOKEN` does not trigger other workflows, so `release-please.yml` calls it when a release was created, passing `secrets: inherit`. Publishing artifacts also needs `id-token: write` and `attestations: write`.
- `conventional-commits.yml` validates every commit in the PR, since merge commits make release-please read each one. Allowed types include `deps`.

## 6. CI lint

- `lint.yml` on changes under `.github/workflows/**`: `uses: non7top/gh-workflows/.github/workflows/actions-lint.yml@main` (actionlint and a schema check).
- Test each new or edited workflow locally with `act` before the first real run.
- Public repos can add CodeQL, dependency review and OpenSSF scorecards.

## 7. Verify

- `check.sh` prints `complete`.
- `gh repo-config push --dry-run` prints "No changes".
- The first PR gets the `RELEASE` label and a forecast comment; the first `feat:` or `fix:` on the default branch makes release-please open its release PR.
- Everything goes in through a PR, with its own go-ahead to merge.
