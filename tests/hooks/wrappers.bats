#!/usr/bin/env bats
# The generated pre-commit framework wrappers:
#   pre-commit.d/pre-commit-global   (global config ~/.git/.pre-commit-config.yaml)
#   pre-commit.d/pre-commit-py       (repo .pre-commit-config.yaml, skipped when absent)
#   commit-msg.d/pre-commit-py       (same, commit-msg stage, receives the message file)

load helpers

setup() {
    common_setup
    make_origin
    PY=$HOME/.local/share/uv/tools/pre-commit/bin/python
}

fake_install_python() {
    mkdir -p "$(dirname "$PY")"
    printf '#!/bin/sh\necho "python $*" >> "$STUB_LOG_DIR/pre-commit.log"\n' > "$PY"
    chmod +x "$PY"
}

@test "pre-commit-global: uses pre-commit from PATH with the global config" {
    run "$HOOKS/pre-commit.d/pre-commit-global"
    assert_success
    run stub_calls pre-commit
    assert_output "hook-impl --config=$HOME/.git/.pre-commit-config.yaml --hook-type=pre-commit --hook-dir $HOOKS/pre-commit.d --"
}

@test "pre-commit-py: repo config, skipped when missing" {
    run "$HOOKS/pre-commit.d/pre-commit-py"
    assert_success
    run stub_calls pre-commit
    assert_output "hook-impl --config=.pre-commit-config.yaml --hook-type=pre-commit --skip-on-missing-config --hook-dir $HOOKS/pre-commit.d --"
}

@test "commit-msg.d/pre-commit-py: commit-msg stage, message file passed through" {
    run "$HOOKS/commit-msg.d/pre-commit-py" .git/COMMIT_EDITMSG
    assert_success
    run stub_calls pre-commit
    assert_output "hook-impl --config=.pre-commit-config.yaml --hook-type=commit-msg --skip-on-missing-config --hook-dir $HOOKS/commit-msg.d -- .git/COMMIT_EDITMSG"
}

@test "pre-commit failure fails the hook" {
    for h in pre-commit.d/pre-commit-global pre-commit.d/pre-commit-py commit-msg.d/pre-commit-py; do
        PRE_COMMIT_STUB_RC=1 run "$HOOKS/$h"
        assert_failure 1
    done
}

@test "the uv-installed python is preferred over pre-commit on PATH" {
    fake_install_python
    run "$HOOKS/pre-commit.d/pre-commit-global"
    assert_success
    run stub_calls pre-commit
    assert_output --partial "python -mpre_commit hook-impl --config=$HOME/.git/.pre-commit-config.yaml"
}

@test "pre-commit missing everywhere: fails with a message" {
    rm "$T/bin/pre-commit"
    for h in pre-commit.d/pre-commit-global pre-commit.d/pre-commit-py commit-msg.d/pre-commit-py; do
        run "$HOOKS/$h"
        assert_failure 1
        assert_output --partial "pre-commit\` not found"
    done
}
