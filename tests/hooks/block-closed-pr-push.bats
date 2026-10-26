#!/usr/bin/env bats
# pre-push.d/block-closed-pr-push, run directly with the pre-push stdin protocol
#   <local ref> <local sha> <remote ref> <remote sha>   (args: remote name, remote url)
# Through real git and the dispatcher: integration.bats.
#
# Contract: nothing may be pushed onto a branch whose PR is closed/merged. This hook is the
# enforcement point that lets the commit hook allow new branches cut from merged ones.

load helpers

setup() {
    common_setup
    make_origin
    make_merged_branch
    SHA=1111111111111111111111111111111111111111
    ZERO40=0000000000000000000000000000000000000000
    ZERO64=0000000000000000000000000000000000000000000000000000000000000000
}

# push_hook <remote> <refspec lines...>: feed "refs/heads/local <sha> <remote ref> <sha>" lines
push_hook() {
    local remote=$1 input=""
    shift
    for line in "$@"; do input+="$line"$'\n'; done
    run "$HOOKS/pre-push.d/block-closed-pr-push" "$remote" "$T/origin.git" <<<"$input"
}

branch_line() { echo "refs/heads/${2:-local} $SHA refs/heads/$1 $ZERO40"; }

# -- blocked ------------------------------------------------------------------------------------

@test "push onto a merged branch is blocked" {
    push_hook origin "$(branch_line "$MERGED_BR")"
    assert_failure 1
    assert_output --partial "Push blocked: branch '$MERGED_BR' has a MERGED pull request."
    assert_output --partial "Create a new branch"
    assert_gh_queried_closed_prs "$MERGED_BR"
}

@test "push of a differently named local branch onto a merged branch is blocked" {
    push_hook origin "$(branch_line "$MERGED_BR" from-merged)"
    assert_failure 1
}

@test "push onto a CLOSED (not merged) PR's branch is blocked" {
    gh_stub_pr abandoned CLOSED
    push_hook origin "$(branch_line abandoned)"
    assert_failure 1
    assert_output --partial "has a CLOSED pull request"
}

@test "branch name with a slash is queried verbatim and blocked" {
    gh_stub_pr feature/done MERGED
    push_hook origin "$(branch_line feature/done)"
    assert_failure 1
    assert_gh_queried_closed_prs feature/done
}

@test "one merged branch among several pushed refs blocks the whole push" {
    push_hook origin "$(branch_line fresh)" "$(branch_line "$MERGED_BR")" "$(branch_line fresh2)"
    assert_failure 1
    assert_output --partial "'$MERGED_BR'"
}

@test "every merged branch among the pushed refs is reported" {
    gh_stub_pr second MERGED
    push_hook origin "$(branch_line "$MERGED_BR")" "$(branch_line second)"
    assert_failure 1
    assert_output --partial "'$MERGED_BR'"
    assert_output --partial "'second'"
}

@test "a new remote sha (non-zero remote side) is still checked" {
    push_hook origin "refs/heads/x $SHA refs/heads/$MERGED_BR 2222222222222222222222222222222222222222"
    assert_failure 1
}

# -- allowed ------------------------------------------------------------------------------------

@test "push to a fresh branch name is allowed" {
    push_hook origin "$(branch_line fresh)"
    assert_success
    assert_gh_queried_closed_prs fresh
}

@test "open PR only: allowed" {
    gh_stub_pr wip OPEN
    push_hook origin "$(branch_line wip)"
    assert_success
}

@test "deleting a merged remote branch is allowed (cleanup), sha1 and sha256 zero ids" {
    push_hook origin "(delete) $ZERO40 refs/heads/$MERGED_BR $SHA"
    assert_success
    push_hook origin "(delete) $ZERO64 refs/heads/$MERGED_BR $SHA"
    assert_success
    assert_gh_not_called
}

@test "main, master and develop are skipped without asking gh" {
    for b in main master develop; do
        gh_stub_pr "$b" MERGED
        push_hook origin "$(branch_line "$b")"
        assert_success
    done
    assert_gh_not_called
}

@test "tags and other non-branch refs are skipped" {
    gh_stub_pr v1 MERGED
    push_hook origin "refs/tags/v1 $SHA refs/tags/v1 $ZERO40" "refs/heads/x $SHA refs/notes/commits $ZERO40"
    assert_success
    assert_gh_not_called
}

@test "empty ref list is allowed" {
    push_hook origin
    assert_success
}

# -- scope limits (documented gaps) -----------------------------------------------------------

@test "KNOWN GAP: pushes to a remote other than origin are not checked" {
    push_hook fork "$(branch_line "$MERGED_BR")"
    assert_success
    assert_gh_not_called
}

# -- gh unavailable: advisory ------------------------------------------------------------------

@test "gh missing: warns and allows" {
    gh_stub_absent
    push_hook origin "$(branch_line "$MERGED_BR")"
    assert_success
    assert_output --partial "'gh' not found; skipping closed-PR check"
}

@test "gh unauthenticated: warns and allows" {
    gh_stub_auth_rc 1
    push_hook origin "$(branch_line "$MERGED_BR")"
    assert_success
    assert_output --partial "'gh' is not authenticated; skipping closed-PR check"
}

@test "gh pr list failing: allowed" {
    gh_stub_pr_list_rc 1
    push_hook origin "$(branch_line "$MERGED_BR")"
    assert_success
}
