#!/usr/bin/env bats
# The multi-hook dispatchers: pre-commit, commit-msg and pre-push run every script in their .d/ dir.
# Tested here with fake .d/ scripts; the real .d/ contents are covered in integration.bats.

load helpers

setup() {
    common_setup
    D=$T/dispatch
    mkdir -p "$D"
    cp "$HOOKS"/pre-commit "$HOOKS"/commit-msg "$HOOKS"/pre-push "$D/"
    ORDER=$T/order.log
}

# fake_script <hook> <name> <exit code>: logs "<name> <args>" and, for pre-push, its stdin
fake_script() {
    mkdir -p "$D/$1.d"
    cat > "$D/$1.d/$2" <<SCRIPT
#!/bin/bash
echo "$2 \$*" >> "$ORDER"
[[ "$1" == pre-push ]] && echo "$2 stdin: \$(cat)" >> "$ORDER"
exit $3
SCRIPT
    chmod +x "$D/$1.d/$2"
}

# -- pre-commit and commit-msg --------------------------------------------------------------

@test "pre-commit: runs every script in name order and passes when all pass" {
    fake_script pre-commit b 0
    fake_script pre-commit a 0
    fake_script pre-commit c 0
    run "$D/pre-commit"
    assert_success
    assert_equal "$(cat "$ORDER")" "$(printf 'a \nb \nc ')"
    assert_output --partial "[ OK ]"
    refute_output --partial "[ ERROR ]"
}

@test "pre-commit: a failing script fails the hook but the rest still run" {
    fake_script pre-commit a 0
    fake_script pre-commit b 1
    fake_script pre-commit c 0
    run "$D/pre-commit"
    assert_failure 1
    assert_equal "$(cat "$ORDER")" "$(printf 'a \nb \nc ')"
    assert_output --partial "[ ERROR ]"
    assert_output --partial "pre-commit.d/b"
}

@test "pre-commit: every failing script is reported" {
    fake_script pre-commit a 1
    fake_script pre-commit b 1
    run "$D/pre-commit"
    assert_failure 1
    [[ $(grep -c "\[ ERROR \]" <<<"$output") -eq 2 ]]
}

@test "pre-commit: a non-executable script fails the hook instead of being skipped silently" {
    fake_script pre-commit a 0
    chmod -x "$D/pre-commit.d/a"
    run "$D/pre-commit"
    assert_failure 1
}

@test "pre-commit: no scripts at all fails (the unexpanded glob is run)" {
    mkdir "$D/pre-commit.d"
    run "$D/pre-commit"
    assert_failure 1
}

@test "commit-msg: passes the message file to every script" {
    fake_script commit-msg a 0
    fake_script commit-msg b 0
    run "$D/commit-msg" .git/COMMIT_EDITMSG
    assert_success
    assert_equal "$(cat "$ORDER")" "$(printf 'a .git/COMMIT_EDITMSG\nb .git/COMMIT_EDITMSG')"
}

@test "commit-msg: a failing script fails the hook but the rest still run" {
    fake_script commit-msg a 1
    fake_script commit-msg b 0
    run "$D/commit-msg" msgfile
    assert_failure 1
    assert_equal "$(cat "$ORDER")" "$(printf 'a msgfile\nb msgfile')"
}

# -- pre-push -----------------------------------------------------------------------------------

@test "pre-push: git-lfs and every script get the arguments and the full ref list on stdin" {
    fake_script pre-push a 0
    fake_script pre-push b 0
    run "$D/pre-push" origin url <<<"refs/heads/x 1 refs/heads/x 0"
    assert_success
    assert_equal "$(stub_calls git-lfs)" "pre-push origin url"
    assert_equal "$(cat "$STUB_LOG_DIR/git-lfs.stdin")" "refs/heads/x 1 refs/heads/x 0"
    assert_equal "$(cat "$ORDER")" "$(printf 'a origin url\na stdin: refs/heads/x 1 refs/heads/x 0\nb origin url\nb stdin: refs/heads/x 1 refs/heads/x 0')"
}

@test "pre-push: a failing script fails the push, later scripts and git-lfs still ran" {
    fake_script pre-push a 1
    fake_script pre-push b 0
    run "$D/pre-push" origin url <<<"refs/heads/x 1 refs/heads/x 0"
    assert_failure 1
    grep -q '^b ' "$ORDER"
    assert [ -n "$(stub_calls git-lfs)" ]
}

@test "pre-push: a failing git-lfs fails the push, scripts still run" {
    fake_script pre-push a 0
    GIT_LFS_STUB_RC=1 run "$D/pre-push" origin url <<<"refs/heads/x 1 refs/heads/x 0"
    assert_failure 1
    grep -q '^a ' "$ORDER"
}

@test "pre-push: git-lfs missing: exit 2 with an explanation, scripts not run" {
    rm "$T/bin/git-lfs"
    fake_script pre-push a 0
    run "$D/pre-push" origin url <<<"refs/heads/x 1 refs/heads/x 0"
    assert_failure 2
    assert_output --partial "'git-lfs' was not found on your path"
    assert [ ! -e "$ORDER" ]
}

@test "pre-push: no scripts at all fails (the unexpanded glob is run)" {
    mkdir "$D/pre-push.d"
    run "$D/pre-push" origin url <<<""
    assert_failure 1
}
