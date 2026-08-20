#!/usr/bin/env bash
# Sync-behavior scenarios for the dotfiles tool, run against a scratch
# HOME inside the disposable test container (make test). Never touches
# the real home directory: everything goes through -R/-H/-C overrides.
set -uo pipefail

REPO=${REPO:-/repo}
FAKEHOME=$(mktemp -d)

DF() { dotfiles -C "$REPO/.dotfilesrc" -R "$REPO" -H "$FAKEHOME" "$@"; }

pass=0 fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

echo "== repo config sanity (same check CI runs)"
if python3 "$REPO/.github/scripts/check_dotfiles_config.py"; then
    ok "check_dotfiles_config.py passes"
else
    bad "check_dotfiles_config.py failed"
fi

echo "== fresh sync into empty home"
DF --sync >/dev/null
if [ -L "$FAKEHOME/.bashrc" ]; then
    ok "top-level file linked (.bashrc)"
else
    bad "top-level file not linked (.bashrc)"
fi
if [ -L "$FAKEHOME/.claude/skills" ]; then
    ok "package entry linked (.claude/skills)"
else
    bad "package entry not linked (.claude/skills)"
fi
if [ -z "$(DF --check)" ]; then
    ok "--check clean after fresh sync"
else
    bad "--check not clean after fresh sync"
fi

echo "== wrong-target symlink (dead checkout scenario)"
ln -sfn /nonexistent/old-checkout "$FAKEHOME/.claude/skills"
if DF --check | grep -q "skills.*unsynced"; then
    ok "--check reports wrong-target link as unsynced"
else
    bad "--check missed wrong-target link"
fi
DF --sync >/dev/null
if [ "$(readlink "$FAKEHOME/.claude/skills")" = /nonexistent/old-checkout ]; then
    ok "plain --sync skips it (no silent overwrite)"
else
    bad "plain --sync overwrote without --force"
fi
DF --sync --force >/dev/null
if [ "$(readlink -f "$FAKEHOME/.claude/skills")" = "$(readlink -f "$REPO/claude/_skills")" ]; then
    ok "--sync --force repairs it"
else
    bad "--sync --force did not repair it"
fi

echo "== real-file collision"
rm "$FAKEHOME/.tigrc"
echo "local edits" > "$FAKEHOME/.tigrc"
if DF --check | grep -q "tigrc.*unsynced"; then
    ok "--check reports real-file collision"
else
    bad "--check missed real-file collision"
fi
DF --sync --force >/dev/null
if [ -L "$FAKEHOME/.tigrc" ]; then
    ok "--sync --force replaces file with symlink"
else
    bad "--sync --force did not replace file"
fi

echo "== documented blind spot: orphaned links are invisible to --check"
ln -s /nonexistent "$FAKEHOME/.orphan"
if DF --check | grep -q orphan; then
    bad "--check saw the orphan (blind spot closed? update docs/tests)"
else
    ok "--check silent on orphan link, as documented"
fi
if [ -n "$(find "$FAKEHOME" -maxdepth 1 -xtype l)" ]; then
    ok "find -xtype l detects the orphan"
else
    bad "find -xtype l did not detect the orphan"
fi
rm "$FAKEHOME/.orphan"

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
