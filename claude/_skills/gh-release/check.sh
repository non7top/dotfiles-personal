#!/usr/bin/env bash
# Read-only audit of release workflows. Usage: check.sh [repo-path...]
set -u
[ $# -eq 0 ] && set -- .
bad=0

for repo in "$@"; do
  wf="$repo/.github/workflows"
  [ -d "$wf" ] || continue
  shopt -s nullglob
  for f in "$wf"/*.yml "$wf"/*.yaml; do
    grep -qE 'gh release (upload|create)|action-gh-release|run: (npm run|make) publish' "$f" || continue
    name="${repo##*/}: ${f##*/}"
    gap() { echo "$name: $1"; bad=1; }

    grep -qE 'attest-build-provenance' "$f" || gap "no build provenance attestation"
    grep -qE 'cosign sign-blob|apt-cosign-sign|apksigner' "$f" || gap "artifacts are not signed (cosign, apt-cosign-sign or apksigner)"
    grep -qE 'id-token: *write' "$f" || gap "missing id-token: write"
    if grep -q 'attest-build-provenance' "$f"; then
      grep -qE 'attestations: *write' "$f" || gap "attests but has no attestations: write"
    fi
    grep -q 'workflow_dispatch' "$f" || gap "no workflow_dispatch to backfill a release"
    if grep -qE '^ +tags:' "$f" && ! grep -qE 'workflow_run|workflow_call' "$f"; then
      gap "triggers on push tags only, which release-please tags do not fire"
    fi
    grep -qE 'gh release upload' "$f" && ! grep -q -- '--clobber' "$f" && gap "gh release upload without --clobber, a re-run fails"
    grep -qE 'SHA256SUMS|sha256sum|apt-cosign-sign' "$f" || gap "no checksums"
    grep -qE 'uses: [^ ]+@(main|master|latest)$' "$f" && gap "an action is pinned to a branch"
  done
  shopt -u nullglob
done

[ "$bad" -eq 0 ] && echo "complete"
exit "$bad"
