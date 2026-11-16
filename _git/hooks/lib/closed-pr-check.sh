# Sourced by pre-commit.d/block-closed-pr-branch and pre-push.d/block-closed-pr-push.

# closed_pr_check <branch> <Action> [[HOST/]OWNER/REPO]: return 1 if the branch has a closed or merged PR.
# Without a repo, gh resolves it from the current directory (origin).
# gh is advisory -- missing or unauthenticated gh is a warning, not a hard failure.
closed_pr_check() {
    local branch=$1 action=$2 repo=${3:-} pr_state

    if ! command -v gh &>/dev/null; then
        echo "Warning: 'gh' not found; skipping closed-PR check." >&2
        return 0
    fi

    if ! gh auth status &>/dev/null; then
        echo "Warning: 'gh' is not authenticated; skipping closed-PR check." >&2
        return 0
    fi

    pr_state=$(gh pr list ${repo:+-R "$repo"} --head "$branch" --state closed --json state --jq '.[0].state' 2>/dev/null || true)

    if [[ "$pr_state" == "CLOSED" || "$pr_state" == "MERGED" ]]; then
        echo "$action blocked: branch '$branch' has a ${pr_state} pull request." >&2
        echo "Create a new branch for your changes." >&2
        return 1
    fi
}
