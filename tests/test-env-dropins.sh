#!/usr/bin/env bash
# Tests the ~/.env.d and ~/.env_local.d loop from _bashrc and the claude drop-in.
# Runs inside the disposable test container (make test-env-dropins).
set -uo pipefail

REPO=${REPO:-$(cd "$(dirname "$0")/.." && pwd)}
pass=0 fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

LOOP=$(sed -n '/^for d in "\$HOME\/.env.d"/,/^done$/p' "$REPO/_bashrc")
run() { env -i HOME="$SCRATCH" bash -c "$LOOP; $1"; }

echo "== loop extracted from _bashrc"
if [ -n "$LOOP" ]; then ok "loop found"; else bad "loop not found in _bashrc"; fi

echo "== no drop-in dirs"
out=$(run 'echo done')
if [ "$out" = "done" ]; then ok "missing dirs are skipped without error"; else bad "missing dirs: got '$out'"; fi

echo "== local overrides shared"
mkdir -p "$SCRATCH/.env.d" "$SCRATCH/.env_local.d"
printf 'export X=shared\nexport Y=shared\n' > "$SCRATCH/.env.d/a.env"
printf 'export X=local\n' > "$SCRATCH/.env_local.d/a.env"
printf 'export Z=ignored\n' > "$SCRATCH/.env.d/not-env.txt"
out=$(run 'echo "$X $Y ${Z-unset}"')
if [ "$out" = "local shared unset" ]; then
    ok "~/.env_local.d wins, shared values kept, non-.env files ignored"
else
    bad "expected 'local shared unset', got '$out'"
fi

echo "== claude drop-in"
rm -rf "$SCRATCH/.env.d" "$SCRATCH/.env_local.d"
mkdir -p "$SCRATCH/.env.d"
cp "$REPO/_env.d/claude.env" "$SCRATCH/.env.d/claude.env"
out=$(run 'echo "$CLAUDE_CODE_TMPDIR"')
if [ "$out" = "$SCRATCH/.claude/scratchpad" ]; then
    ok "CLAUDE_CODE_TMPDIR expands \$HOME"
else
    bad "expected '$SCRATCH/.claude/scratchpad', got '$out'"
fi

echo
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
