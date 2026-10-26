#!/usr/bin/env bats
# pre-commit.d/block-closed-pr-branch
#
# Contract: no work may land on a branch whose PR is closed/merged, and a valid commit must never
# be blocked. A commit the hook allows onto a merged branch's history must be caught at push time
# (see block-closed-pr-push.bats and integration.bats).

load helpers

setup() {
    common_setup
    make_origin
    make_merged_branch
}

run_hook() { run "$HOOKS/pre-commit.d/block-closed-pr-branch"; }

# -- skipped branches ---------------------------------------------------------------------------

@test "detached HEAD is skipped" {
    git switch -q --detach master
    run_hook
    assert_success
    assert_gh_not_called
}

@test "default branches are skipped even if a closed PR exists for the name" {
    for b in main master develop; do
        git switch -q -C "$b" origin/master
        gh_stub_pr "$b" MERGED
        run_hook
        assert_success
    done
    assert_gh_not_called
}

# -- valid commits must not be blocked ---------------------------------------------------------

@test "new branch cut from origin/master (switch -c): allowed (issue 41)" {
    git switch -q -c feature origin/master
    run_hook
    assert_success
    assert_gh_queried_closed_prs feature
}

@test "new branch cut from origin/master (checkout -b): allowed" {
    git checkout -q -b feature origin/master
    run_hook
    assert_success
}

@test "new worktree branch cut from origin/master: allowed" {
    git worktree add -q -b wt-feature "$T/wt" origin/master
    cd "$T/wt"
    run_hook
    assert_success
}

@test "new branch with a slash in the name cut from origin/master: allowed" {
    git switch -q -c feature/some-thing origin/master
    run_hook
    assert_success
    assert_gh_queried_closed_prs feature/some-thing
}

@test "branch with no upstream is allowed without asking gh" {
    git switch -q -c local-only --no-track
    run_hook
    assert_success
    assert_gh_not_called
}

@test "new name cut from a merged branch is allowed (it is a new branch)" {
    git switch -q -c from-merged "origin/$MERGED_BR"
    run_hook
    assert_success
}

@test "new name cut from a merged branch is allowed after its remote branch is deleted" {
    git switch -q -c from-merged "origin/$MERGED_BR"
    git_nohooks push -q origin --delete "$MERGED_BR"
    run_hook
    assert_success
}

@test "pushed branch (-u) with its remote present and no PR is allowed" {
    git switch -q -c pushed
    git_nohooks push -q -u origin pushed
    run_hook
    assert_success
    assert_gh_queried_closed_prs pushed
}

# -- closed/merged PR must stay blocked --------------------------------------------------------

@test "the merged branch itself, remote present: blocked" {
    git switch -q "$MERGED_BR"
    run_hook
    assert_failure 1
    assert_output --partial "Commit blocked: branch '$MERGED_BR' has a MERGED pull request."
    assert_output --partial "Create a new branch"
    assert_gh_queried_closed_prs "$MERGED_BR"
}

@test "a CLOSED (not merged) PR blocks too" {
    git switch -q -c abandoned origin/master
    git_nohooks push -q -u origin abandoned
    gh_stub_pr abandoned CLOSED
    run_hook
    assert_failure 1
    assert_output --partial "has a CLOSED pull request"
}

@test "merged branch's name reused, cut from origin/master: blocked" {
    git_nohooks push -q origin --delete "$MERGED_BR"
    git branch -q -D "$MERGED_BR"
    git switch -q -c "$MERGED_BR" origin/master
    run_hook
    assert_failure 1
    assert_output --partial "has a MERGED pull request"
}

@test "branch pushed without -u (upstream origin/master) onto a merged PR's name: blocked" {
    git switch -q -c reused origin/master
    git_nohooks push -q origin reused
    gh_stub_pr reused MERGED
    run_hook
    assert_failure 1
    assert_output --partial "has a MERGED pull request"
}

@test "any closed PR for the name blocks, even when another PR is open" {
    git switch -q -c reopened origin/master
    git_nohooks push -q -u origin reopened
    gh_stub_pr reopened MERGED
    gh_stub_pr reopened OPEN
    run_hook
    assert_failure 1
}

@test "open PR only: allowed (the query asks for closed PRs)" {
    git switch -q -c wip origin/master
    git_nohooks push -q -u origin wip
    gh_stub_pr wip OPEN
    run_hook
    assert_success
}

@test "closed PR of a different branch does not block" {
    git switch -q -c other-name origin/master
    git_nohooks push -q -u origin other-name
    run_hook
    assert_success
}

# -- remote deleted / never pushed: own upstream ----------------------------------------------

@test "own upstream, remote branch deleted (pruned): blocked with both hints" {
    git switch -q "$MERGED_BR"
    git_nohooks push -q origin --delete "$MERGED_BR"
    git config "branch.$MERGED_BR.remote" origin
    git config "branch.$MERGED_BR.merge" "refs/heads/$MERGED_BR"
    run_hook
    assert_failure 1
    assert_output --partial "upstream 'origin/$MERGED_BR' does not exist on the remote"
    assert_output --partial "git push -u origin $MERGED_BR"
    assert_output --partial "switch to a new branch"
}

@test "own upstream, remote branch deleted behind the clone's back: fetch --prune finds it" {
    git switch -q "$MERGED_BR"
    git --git-dir="$T/origin.git" branch -q -D "$MERGED_BR"
    run_hook
    assert_failure 1
    assert_output --partial "does not exist on the remote"
}

@test "own upstream configured but branch never pushed: blocked, says how to create it" {
    git switch -q -c never-pushed origin/master
    git config branch.never-pushed.remote origin
    git config branch.never-pushed.merge refs/heads/never-pushed
    run_hook
    assert_failure 1
    assert_output --partial "git push -u origin never-pushed"
}

@test "remote-gone block does not need gh" {
    git switch -q -c never-pushed origin/master
    git config branch.never-pushed.remote origin
    git config branch.never-pushed.merge refs/heads/never-pushed
    gh_stub_absent
    run_hook
    assert_failure 1
}

# -- gh unavailable: advisory ------------------------------------------------------------------

@test "gh missing: warns and allows" {
    git switch -q "$MERGED_BR"
    gh_stub_absent
    run_hook
    assert_success
    assert_output --partial "'gh' not found; skipping closed-PR check"
}

@test "gh unauthenticated: warns and allows, without listing PRs" {
    git switch -q "$MERGED_BR"
    gh_stub_auth_rc 1
    run_hook
    assert_success
    assert_output --partial "'gh' is not authenticated; skipping closed-PR check"
    run grep -F "pr list" "$STUB_LOG_DIR/gh.log"
    assert_failure
}

@test "gh pr list failing (API/network): allowed" {
    git switch -q "$MERGED_BR"
    gh_stub_pr_list_rc 1
    run_hook
    assert_success
}

# -- offline: fetch fails ----------------------------------------------------------------------

@test "offline: new branch from origin/master still allowed" {
    git switch -q -c feature origin/master
    git remote set-url origin "$T/does-not-exist.git"
    run_hook
    assert_success
}

@test "offline: merged branch with a stale remote ref is still blocked by the PR check" {
    git switch -q "$MERGED_BR"
    git remote set-url origin "$T/does-not-exist.git"
    run_hook
    assert_failure 1
    assert_output --partial "has a MERGED pull request"
}
