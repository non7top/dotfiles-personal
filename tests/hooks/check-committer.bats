#!/usr/bin/env bats
# pre-commit.d/check-committer: user.email must match user.default.<origin domain with dots as dashes>

load helpers

setup() {
    common_setup
    make_origin
    git remote set-url origin git@github.com:example/repo.git
}

run_hook() { run "$HOOKS/pre-commit.d/check-committer"; }

@test "email matches the default for the origin domain: passes" {
    git config user.default.github-com me@example.com
    git config user.email me@example.com
    run_hook
    assert_success
    assert_output ""
}

@test "email differs: blocked, and the right one is printed" {
    git config user.default.github-com expected@example.com
    git config user.email someone-else@example.com
    run_hook
    assert_failure 1
    assert_output --partial "git config user.email expected@example.com"
}

@test "https origin URLs map to the same domain key" {
    git remote set-url origin https://github.com/example/repo.git
    git config user.default.github-com expected@example.com
    git config user.email someone-else@example.com
    run_hook
    assert_failure 1
}

@test "ssh:// origin URLs with a port map to the domain key" {
    git remote set-url origin ssh://git@git.example.org:2222/example/repo.git
    git config user.default.git-example-org expected@example.com
    git config user.email someone-else@example.com
    run_hook
    assert_failure 1
}

@test "no default configured for the domain: not checked" {
    git config user.email anyone@example.com
    run_hook
    assert_success
}

@test "a default for another domain does not apply" {
    git config user.default.bitbucket-org expected@example.com
    git config user.email someone-else@example.com
    run_hook
    assert_success
}

@test "no origin: not checked" {
    git remote remove origin
    git config user.default.github-com expected@example.com
    run_hook
    assert_success
}
