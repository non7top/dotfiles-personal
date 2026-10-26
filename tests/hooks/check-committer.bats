#!/usr/bin/env bats
# pre-commit.d/check-committer: currently disabled (exits 0 before any check). If it is re-enabled,
# replace these tests with ones for the real rule.

load helpers

setup() {
    common_setup
    make_origin
}

@test "disabled: passes regardless of origin and committer email" {
    git remote set-url origin git@github.com:example/repo.git
    git config user.email someone-else@example.com
    git config user.default.github-com expected@example.com
    run "$HOOKS/pre-commit.d/check-committer"
    assert_success
    assert_output ""
}
