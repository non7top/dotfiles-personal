#!/usr/bin/env bash
# Runs the git hook tests (bats) inside the disposable test container: make test-hooks.
# Extra arguments go to bats, e.g. a single file, --filter, or --jobs.
set -euo pipefail
REPO=${REPO:-/repo}
export REPO
exec bats --print-output-on-failure "$@" "$REPO/tests/hooks" < /dev/null
