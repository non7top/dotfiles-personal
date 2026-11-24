---
name: gh-release
description: Use when writing, changing, debugging or auditing the workflow that builds and publishes a release on GitHub. Covers how release-please hands over to release.yml, per-platform recipes (Windows exe and installers, Android APK, apt .deb and signed apt repo, PyPI, GitHub Action tags), build provenance attestation, cosign signing, the forecast in PR builds, verification commands, and check.sh to audit repos.
---

# GitHub release workflows

Setup of release-please itself (config, manifest, forecast preview, Dependabot) is in the `new-repo` skill. This one covers what runs after a release PR merges: build, sign, attest, upload.

```
~/.claude/skills/gh-release/check.sh [repo-path...]
```

Read-only, defaults to the current directory, exits 1 on any gap. It reads `.github/workflows/*.yml` that upload release assets.

## 1. The hand-over

release-please makes the tag and the GitHub release with `GITHUB_TOKEN`, and a tag made that way does not trigger `on: push: tags`. Two wirings work, and both exist in the repos:

- **A, `workflow_run`** (most repos): `release.yml` runs on `workflow_run` of `release-please` (completed) and on `workflow_dispatch` with a `tag` input. A first job `check-release-tag` finds the `vX.Y.Z` tag pointing at the triggering commit (`git tag --points-at HEAD | grep -E ... || true`); the build job runs only when that tag is non-empty. Keeps the shared `non7top/gh-workflows` release-please workflow, which has no outputs.
- **B, `workflow_call`**: a local `release-please.yml` (the action directly, with `release_created` and `tag_name` outputs) calls `./.github/workflows/release.yml` with `tag`, `publish` and `secrets: inherit`. Fewer moving parts, but the shared workflow and its `RELEASE` label step are not used.

Either way:
- Check out the exact commit (`workflow_run.head_sha`), never the default branch tip. A manual backfill checks out the dispatch ref, not the tag, so a fix to the release process takes effect.
- Job permissions: `contents: write`, `id-token: write`, and `attestations: write` when attesting.
- Release builds must be reproducible from the tag's commit alone: no `latest` downloads in the build.

## 2. The artifact pipeline

Order in the job, for every platform:

1. Build. Put the version in the file name or a version resource (`${TAG#v}`).
2. `SHA256SUMS` over the files that ship.
3. **Attest provenance** on the final bytes:
   ```
   - uses: actions/attest-build-provenance@<pinned>
     with:
       subject-path: |
         dist/app-*.exe
         dist/SHA256SUMS
   ```
   Attestation is by digest. Nothing may rewrite, re-sign or re-zip a file afterwards, or its attestation no longer matches.
4. **Sign** keyless with cosign: `sigstore/cosign-installer`, then `cosign sign-blob --yes --bundle "$f.cosign.bundle" "$f"` per file. The job's OIDC token buys a short-lived certificate and the signature goes to Rekor; no key is held.
5. Upload to the existing release: `gh release upload "$TAG" --clobber --repo "$GITHUB_REPOSITORY" <files> <bundles>`. `--clobber` makes a backfill re-run safe.

Rules from past failures:
- Fail when a glob matches nothing (`shopt -s nullglob` plus a counter, `if [ "$signed" -eq 0 ]; then exit 1`). A silent empty loop once shipped a release with no signatures.
- Quote file names and never pass a list through a text file or an unquoted `$(cat ...)`: a product name with a space split one path into three arguments.
- Pin actions to a tag and let Dependabot move them.
- Asset names carry the tag, so downloads are distinguishable.

## 3. Per platform

**Windows exe from a compiled language.** A `windows-latest` job (`cargo build --release --locked`), copy the exe to a name with the tag, then step 2 onward. A Linux job with mingw or a Wine container produces the same artifact on a cheaper runner (`make` target shared with local builds).

**Windows installer (Electron, NSIS).** Build and publish with electron-builder, which reads `GH_TOKEN` (set `GITHUB_TOKEN` too). One repo cross-builds under Wine in a container on `ubuntu-latest`; another uses `windows-latest` because NSIS needed a real Windows host. Attest both the installer and the exe it installs, since their hashes differ. Run bundle sanity checks (externals, no debug build flag) before the publish step.

**Windows DLL, installer and CLI cross-built on Linux.** `make dll cli-win build installer package`, attest every shipped file plus `SHA256SUMS`, sign each. A `PROVENANCE_REPO` env var is set only in `release.yml`, so only release builds claim to come from the repo's workflow; PR builds do not set it.

**Android APK.** Keystore from a base64 secret into `$RUNNER_TEMP`, `./gradlew assembleRelease`, then `apksigner verify --print-certs`, `SHA256SUMS`, attest, upload. The APK is signed by the keystore, so no cosign. Give `release.yml` a `publish` boolean (default true): `false` builds and verifies only, which is what `act` runs. act passes booleans as strings, so compare `format('{0}', inputs.publish) == 'true'`. A version stored in `build.gradle.kts` goes in release-please `extra-files` (`generic`).

**Debian package and signed apt repo.** Build the .deb in a container on the runner, then install-test it in `ubuntu:22.04`, `24.04` and `26.04` containers (jammy/22.04, noble/24.04, resolute/26.04). Sign with `apt-cosign-sign` natively on the runner (it needs the job's OIDC variables, which a nested container does not get). Upload `*.deb` and `*.deb.sigstore`. Publish the apt repo with the composite actions from `non7top/apt-cosign` pinned to a tag: `fetch-apt-cosign-sign` (version input) and `publish-apt-repo` (force-pushes a flat repo to the `apt-repo` branch). Set `codename-pattern` when builds per codename differ (different `Depends`), so each gets its own index. Reuse the .deb that was signed: a second build gives a byte-different package (`dpkg-deb` embeds a timestamp). Consumers add `deb [trusted=yes] sigstore+https://raw.githubusercontent.com/OWNER/REPO/refs/heads/apt-repo/ ./`. A package that tracks an upstream (rebuild when the distro's version moves) runs on a schedule with a cheap check job first and `gh release create` with its own tag scheme instead of release-please.

**PyPI.** A separate job after the release job: `environment: pypi`, `id-token: write` only, trusted publishing (`pypa/gh-action-pypi-publish`), no token secret. Pass the distributions between jobs with `upload-artifact`, check the wheel and sdist file names match the tag, and publish only plain `X.Y.Z` tags (prereleases skip PyPI).

**GitHub Action repo.** After the release, force-move the major tag (`v1`) onto the release commit with a `publish-tag.yml` that has both `push: tags` and `workflow_call`; a missed move leaves `@v1` consumers on old code with no signal. The repo's own PR preview uses `uses: ./` so a PR tests the action as it would change it.

## 4. PR builds mirror the release

`build.yml` on `pull_request` should prove the release steps will work before a release runs them:
- **Forecast**: `non7top/release-please-forecast@v1` with `post-comment: 'false'` (needs `fetch-depth: 0`), then `git checkout <the sha checked out before>`, because the action leaves the tree on its own `preview-merge` branch. Name PR artifacts `<predicted>-rc<PR number>`, or the short sha when nothing would release.
- **Cosign dry run** on one built file: `cosign sign-blob` then `cosign verify-blob` with `--certificate-identity-regexp "^https://github.com/<owner>/<repo>/"` and `--certificate-oidc-issuer https://token.actions.githubusercontent.com`; delete the bundle after. Needs `id-token: write`. Skip it for `github.actor == 'dependabot[bot]'`, which gets no OIDC token.
- Upload artifacts and comment the download link on the PR.
- Test `release.yml` with `act` and `publish: false` where the workflow has that input.

## 5. Verify a release

- `gh release view <tag> --json assets -q '.assets[].name'`: every platform file, `SHA256SUMS` and one `.cosign.bundle` per file.
- `gh attestation verify <file> --repo <owner>/<repo>`.
- `cosign verify-blob --bundle <file>.cosign.bundle --certificate-identity-regexp '^https://github\.com/<owner>/<repo>/\.github/workflows/release\.yml@.+$' --certificate-oidc-issuer https://token.actions.githubusercontent.com <file>`.
- Put the `gh attestation verify` line in the README, next to the download instructions.
- A failed upload is repaired with `workflow_dispatch` and the tag, not by editing the release by hand.
