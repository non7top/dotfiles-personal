#!/usr/bin/env bats
# post-checkout, post-commit, post-merge: git-lfs forwarders

load helpers

setup() {
    common_setup
    make_origin
}

@test "forwards to git lfs <hook> with the hook's arguments" {
    for h in post-checkout post-commit post-merge; do
        rm -f "$STUB_LOG_DIR/git-lfs.log"
        run "$HOOKS/$h" a b c
        assert_success
        run stub_calls git-lfs
        assert_output "$h a b c"
    done
}

@test "a failing git-lfs fails the hook" {
    for h in post-checkout post-commit post-merge; do
        GIT_LFS_STUB_RC=1 run "$HOOKS/$h"
        assert_failure 1
    done
}

@test "git-lfs missing: exit 2 with an explanation" {
    rm "$T/bin/git-lfs"
    for h in post-checkout post-commit post-merge; do
        run "$HOOKS/$h"
        assert_failure 2
        assert_output --partial "'git-lfs' was not found on your path"
        assert_output --partial "'$h' file"
    done
}
