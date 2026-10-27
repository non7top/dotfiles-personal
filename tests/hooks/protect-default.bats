#!/usr/bin/env bats
# pre-commit.d/protect-default: no commits on the local default branch (per origin/HEAD, via `git sd`)

load helpers

setup() {
    common_setup
    make_origin
}

run_hook() { run "$HOOKS/pre-commit.d/protect-default"; }

@test "commit on the default branch is blocked" {
    run_hook
    assert_failure 1
    assert_output --partial "Can not commit to the local default branch"
}

@test "commit on a feature branch is allowed" {
    git switch -q -c feature
    run_hook
    assert_success
}

@test "default branch follows origin/HEAD: main is protected, master is not" {
    git switch -q -c main
    git_nohooks push -q origin main
    git remote set-head origin main >/dev/null
    run_hook
    assert_failure 1
    git switch -q master
    run_hook
    assert_success
}

@test "KNOWN ISSUE: origin/HEAD unset: git sd yields \"HEAD\", so nothing is protected and no warning shows" {
    git remote set-head origin --delete >/dev/null
    run git sd
    assert_output --partial "HEAD"
    run_hook
    assert_success
    refute_output --partial "could not determine default branch"
}

@test "no remote at all: allows silently" {
    git remote remove origin
    run_hook
    assert_success
    refute_output --partial "protect-default"
}

@test "KNOWN ISSUE: detached HEAD is blocked (symbolic-ref fails under set -e), e.g. during a rebase" {
    git switch -q --detach master
    run_hook
    assert_failure
}
