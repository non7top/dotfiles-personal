#!/usr/bin/env bats
# pre-commit.d/run-local-hook: chain to the repo's own .git/hooks/<name>, which core.hooksPath
# would otherwise shadow.

load helpers

setup() {
    common_setup
    make_origin
}

local_hook() {   # local_hook <name> <exit code>
    mkdir -p .git/hooks
    printf '#!/bin/sh\necho "local ran with: $*"\nexit %s\n' "$2" > ".git/hooks/$1"
    chmod +x ".git/hooks/$1"
}

run_hook() { run "$HOOKS/pre-commit.d/run-local-hook" "$@"; }

@test "no local hook: passes" {
    run_hook
    assert_success
    assert_output ""
}

@test "local pre-commit hook is executed" {
    local_hook pre-commit 0
    run_hook
    assert_success
    assert_output --partial "Executing local hook pre-commit"
    assert_output --partial "local ran with:"
}

@test "a failing local hook fails the commit" {
    local_hook pre-commit 1
    run_hook
    assert_failure 1
}

@test "the hook name can be chosen with the first argument, and arguments are passed on" {
    local_hook commit-msg 0
    run_hook commit-msg .git/COMMIT_EDITMSG
    assert_success
    assert_output --partial "Executing local hook commit-msg"
    assert_output --partial "local ran with: commit-msg .git/COMMIT_EDITMSG"
}

@test "works from a subdirectory of the repo" {
    local_hook pre-commit 1
    mkdir sub && cd sub
    run_hook
    assert_failure 1
}

@test "KNOWN GAP: in a linked worktree .git is a file, so the local hook is skipped" {
    local_hook pre-commit 1
    git worktree add -q -b wt "$T/wt" origin/master
    cd "$T/wt"
    run_hook
    assert_success
}
