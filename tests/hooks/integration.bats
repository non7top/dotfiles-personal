#!/usr/bin/env bats
# The installed hook set, driven by real git (core.hooksPath -> a copy of _git/hooks): wiring,
# manifest, and the end-to-end contract that nothing lands on a closed/merged PR's branch.

load helpers

setup() {
    common_setup
    make_origin
    make_merged_branch
    use_hooks_path
}

stage_change() { echo "$RANDOM" >> change.txt; git add change.txt; }

# -- manifest: a hook cannot be dropped or left non-executable unnoticed ------------------------

@test "manifest: dispatchers, .d scripts and lib are present and executable" {
    for f in pre-commit commit-msg pre-push post-checkout post-commit post-merge \
        pre-commit.d/block-closed-pr-branch pre-commit.d/check-committer \
        pre-commit.d/pre-commit-global pre-commit.d/pre-commit-py pre-commit.d/protect-default \
        pre-commit.d/run-local-hook pre-commit.d/terraform-docs \
        commit-msg.d/pre-commit-py pre-push.d/block-closed-pr-push; do
        [[ -x "$HOOKS_SRC/$f" ]] || { echo "not executable or missing: $f"; return 1; }
    done
    [[ -f "$HOOKS_SRC/lib/closed-pr-check.sh" ]]
}

@test "manifest: the .d directories hold exactly the expected scripts" {
    assert_equal "$(ls "$HOOKS_SRC/pre-commit.d" | tr '\n' ' ')" \
        "block-closed-pr-branch check-committer pre-commit-global pre-commit-py protect-default run-local-hook terraform-docs "
    assert_equal "$(ls "$HOOKS_SRC/commit-msg.d" | tr '\n' ' ')" "pre-commit-py "
    assert_equal "$(ls "$HOOKS_SRC/pre-push.d" | tr '\n' ' ')" "block-closed-pr-push "
}

@test "both closed-PR hooks share one check (lib) and state the contract" {
    grep -q 'closed-pr-check.sh' "$HOOKS_SRC/pre-commit.d/block-closed-pr-branch"
    grep -q 'closed-pr-check.sh' "$HOOKS_SRC/pre-push.d/block-closed-pr-push"
    grep -q '^# Contract:' "$HOOKS_SRC/pre-commit.d/block-closed-pr-branch"
    grep -q '^# Contract:' "$HOOKS_SRC/pre-push.d/block-closed-pr-push"
}

# -- commits through real git -------------------------------------------------------------------

@test "commit on a new branch cut from origin/master succeeds, every pre-commit script ran OK" {
    git switch -q -c feature origin/master
    stage_change
    run git commit -qm "feature"
    assert_success
    for s in block-closed-pr-branch check-committer pre-commit-global pre-commit-py protect-default run-local-hook terraform-docs; do
        assert_output --partial "pre-commit.d/$s"
    done
    refute_output --partial "[ ERROR ]"
}

@test "commit-msg and post-commit hooks run on a real commit" {
    git switch -q -c feature origin/master
    stage_change
    run git commit -qm "feature"
    assert_success
    stub_calls pre-commit | grep -q -- '--hook-type=commit-msg'
    stub_calls git-lfs | grep -q '^post-commit'
}

@test "commit on the default branch is blocked" {
    stage_change
    run git commit -qm "direct"
    assert_failure
    assert_output --partial "Can not commit to the local default branch"
}

@test "commit on the merged branch is blocked, and that script is marked ERROR" {
    git switch -q "$MERGED_BR"
    stage_change
    run git commit -qm "more work"
    assert_failure
    assert_output --partial "Commit blocked: branch '$MERGED_BR' has a MERGED pull request."
    assert_output --regexp 'pre-commit.d/block-closed-pr-branch.*ERROR'
}

@test "commit on a branch cut from the merged branch is allowed" {
    git switch -q -c continue-work "origin/$MERGED_BR"
    stage_change
    run git commit -qm "continue"
    assert_success
}

@test "one failing pre-commit script blocks the commit even when the others pass" {
    git switch -q -c feature origin/master
    stage_change
    PRE_COMMIT_STUB_RC=1 run git commit -qm "feature"
    assert_failure
}

# -- pushes through real git: the way onto a merged branch is closed ------------------------

@test "contract: from a branch cut from the merged branch, no push form lands on the merged branch" {
    git switch -q -c from-merged "origin/$MERGED_BR"
    commit_file new-work
    before=$(git --git-dir="$T/origin.git" rev-parse "$MERGED_BR")
    for cmd in \
        "push origin from-merged:$MERGED_BR" \
        "push origin HEAD:$MERGED_BR" \
        "push origin refs/heads/from-merged:refs/heads/$MERGED_BR" \
        "push --force origin from-merged:$MERGED_BR" \
        "push --force-with-lease origin from-merged:$MERGED_BR" \
        "-c push.default=upstream push" \
        "-c push.default=upstream push --force"; do
        run git $cmd
        [[ $status -ne 0 ]] || { echo "push was allowed: git $cmd"; return 1; }
        [[ $output == *"Push blocked: branch '$MERGED_BR' has a MERGED pull request."* ]] || { echo "no block message for: git $cmd"; echo "$output"; return 1; }
    done
    assert_equal "$(git --git-dir="$T/origin.git" rev-parse "$MERGED_BR")" "$before"
}

@test "contract: pushing the merged branch itself (plain push) is blocked" {
    git switch -q "$MERGED_BR"
    commit_file more
    run git push
    assert_failure
    assert_output --partial "Push blocked"
}

@test "contract: a branch cut from origin/master force-pushed onto the merged branch's name is blocked" {
    git switch -q -c unrelated origin/master
    commit_file unrelated
    run git push --force origin "unrelated:$MERGED_BR"
    assert_failure
    assert_output --partial "Push blocked"
}

@test "git-lfs sees the real ref list on a push that is allowed" {
    git switch -q -c feature origin/master
    commit_file feature-file
    run git push -u origin feature
    assert_success
    grep -q '^refs/heads/feature ' "$STUB_LOG_DIR/git-lfs.stdin"
}

@test "valid pushes still work: new branch, delete the merged branch, default branch" {
    git switch -q -c feature origin/master
    commit_file feature-file
    run git push -u origin feature
    assert_success
    run git push origin --delete "$MERGED_BR"
    assert_success
    run git push origin feature:master
    assert_success
}
