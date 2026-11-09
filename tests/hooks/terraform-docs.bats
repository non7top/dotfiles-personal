#!/usr/bin/env bats
# pre-commit.d/terraform-docs: regenerate module READMEs with docker and fail if any README changed

load helpers

setup() {
    common_setup
    make_origin
    mkdir -p modules/vpc modules/plain
    touch modules/vpc/.terraform-docs.yml
    commit_file modules/vpc/README.md "# vpc"
    commit_file modules/plain/README.md "# plain"
}

run_hook() { run "$HOOKS/pre-commit.d/terraform-docs"; }

@test "nothing staged: docker is not called" {
    run_hook
    assert_success
    assert [ -z "$(stub_calls docker)" ]
}

@test "staged file in a dir with .terraform-docs.yml: runs terraform-docs there via docker" {
    echo 'x = 1' > modules/vpc/main.tf
    git add modules/vpc/main.tf
    run_hook
    assert_success
    run stub_calls docker
    assert_output --partial "run --rm"
    assert_output --partial "$T/repo/modules/vpc:/terraform-docs"
    assert_output --partial "quay.io/terraform-docs/terraform-docs"
    assert_output --partial "markdown /terraform-docs"
}

@test "staged file in a dir without .terraform-docs.yml: docker is not called" {
    echo 'x = 1' > modules/plain/main.tf
    git add modules/plain/main.tf
    run_hook
    assert_success
    assert [ -z "$(stub_calls docker)" ]
}

@test "terraform-docs rewrites a README: blocked, asks to review the change" {
    echo 'x = 1' > modules/vpc/main.tf
    git add modules/vpc/main.tf
    DOCKER_STUB_APPEND=$T/repo/modules/vpc/README.md run_hook
    assert_failure 1
    assert_output --partial "some README.md files have changed"
}

@test "an unrelated unstaged README.md edit does not block the commit" {
    echo 'x = 1' > modules/plain/main.tf
    git add modules/plain/main.tf
    echo "edited" >> modules/plain/README.md
    run_hook
    assert_success
}

@test "an already-edited README that terraform-docs changes further is blocked" {
    echo 'x = 1' > modules/vpc/main.tf
    git add modules/vpc/main.tf
    echo "edited" >> modules/vpc/README.md
    DOCKER_STUB_APPEND=$T/repo/modules/vpc/README.md run_hook
    assert_failure 1
    assert_output --partial "some README.md files have changed"
}

@test "a module dir with spaces in its name is handled" {
    mkdir "modules/my vpc"
    touch "modules/my vpc/.terraform-docs.yml"
    echo 'x = 1' > "modules/my vpc/main.tf"
    git add "modules/my vpc/main.tf"
    run_hook
    assert_success
    run stub_calls docker
    assert_output --partial "$T/repo/modules/my vpc:/terraform-docs"
}

@test "every staged module dir is processed" {
    echo 'x = 1' > modules/vpc/main.tf
    mkdir modules/other && touch modules/other/.terraform-docs.yml
    echo 'x = 1' > modules/other/main.tf
    git add modules/vpc/main.tf modules/other/main.tf
    run_hook
    assert_success
    run stub_calls docker
    assert_output --partial "$T/repo/modules/other:/terraform-docs"
    assert_output --partial "$T/repo/modules/vpc:/terraform-docs"
}

@test "docker failing fails the commit" {
    echo 'x = 1' > modules/vpc/main.tf
    git add modules/vpc/main.tf
    DOCKER_STUB_RC=1 run_hook
    assert_failure
}

@test "whitespace errors in the staged diff block the commit" {
    printf 'x = 1 \n' > modules/plain/main.tf
    git add modules/plain/main.tf
    run_hook
    assert_failure
    assert_output --partial "trailing whitespace"
}

@test "works for the initial commit (no HEAD yet)" {
    git init -q "$T/fresh"
    cd "$T/fresh"
    echo ok > file
    git add file
    run_hook
    assert_success
}
