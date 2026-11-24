#!/usr/bin/env bash
# Tests _bin/docker-clean against a stub docker.
# Runs inside the disposable test container (make test-docker-clean).
# ok and bad always return 0, so "A && ok || bad" is a safe if/else here.
# shellcheck disable=SC2015
set -uo pipefail

REPO=${REPO:-$(cd "$(dirname "$0")/.." && pwd)}
pass=0 fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

mkdir -p "$SCRATCH/bin"
cat >"$SCRATCH/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$STUB_LOG"
case "$1 $2" in
    "image inspect") [[ " ${STUB_MISSING:-} " != *" $3 "* ]]; exit $? ;;
    "system prune") exit "${STUB_PRUNE_RC:-0}" ;;
esac
[[ $1 == ps ]] && echo stale-pin
exit 0
STUB
chmod +x "$SCRATCH/bin/docker"

run() {
    : >"$SCRATCH/log"
    PATH="$SCRATCH/bin:$PATH" STUB_LOG="$SCRATCH/log" DOCKER_PINNED_IMAGES_FILE="$SCRATCH/list" \
        "$REPO/_bin/docker-clean" "$@" 2>"$SCRATCH/err"
}

printf '# comment\nalpine:3 # trailing\n\n  gone:1\npython:3-slim\n' >"$SCRATCH/list"

echo "== pins and prunes"
STUB_MISSING="gone:1" run -f
rc=$?
creates=$(grep -c '^create .*--label dotfiles.docker-pin ' "$SCRATCH/log")
[ "$creates" = 2 ] && ok "one labelled create per present image" || bad "expected 2 creates, got $creates"
grep -q '^create .* alpine:3$' "$SCRATCH/log" && ok "comments and trailing text are stripped" || bad "alpine:3 not pinned"
grep -q '^create ' <(grep gone:1 "$SCRATCH/log") && bad "missing image was pinned" || ok "missing image is skipped"
grep -q 'gone:1 not present' "$SCRATCH/err" && ok "missing image is reported" || bad "no warning for missing image"
grep -q '^system prune -a --filter label!=dotfiles.docker-pin -f$' "$SCRATCH/log" && ok "prune keeps pins and passes arguments through" || bad "prune line wrong: $(grep prune "$SCRATCH/log")"
[ "$rc" = 0 ] && ok "exit 0" || bad "exit code $rc"

echo "== ordering"
first=$(grep -n '^create ' "$SCRATCH/log" | head -1 | cut -d: -f1)
prune=$(grep -n '^system prune' "$SCRATCH/log" | cut -d: -f1)
last=$(grep -n '^rm ' "$SCRATCH/log" | tail -1 | cut -d: -f1)
if [ "$first" -lt "$prune" ] && [ "$prune" -lt "$last" ]; then ok "pins are created before prune and removed after"; else bad "order: create $first prune $prune rm $last"; fi
grep -q '^rm stale-pin$' "$SCRATCH/log" && ok "leftover pins are removed" || bad "no rm of leftover pins"

echo "== prune failure"
STUB_PRUNE_RC=7 run
rc=$?
[ "$rc" = 7 ] && ok "prune exit code is returned" || bad "expected 7, got $rc"
[ "$(grep -c '^rm ' "$SCRATCH/log")" -ge 2 ] && ok "pins removed after a failed prune" || bad "no cleanup after failure"

echo "== no list"
rm "$SCRATCH/list"
run
rc=$?
grep -q 'nothing pinned' "$SCRATCH/err" && ok "missing list is reported" || bad "no message for missing list"
grep -q '^system prune' "$SCRATCH/log" && [ "$rc" = 0 ] && ok "prune still runs" || bad "prune did not run"

echo
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
