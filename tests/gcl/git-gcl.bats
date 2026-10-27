#!/usr/bin/env bats
# _bin/git-gcl: local branch cleanup against origin/<default>, in scratch repos

load ../hooks/helpers

setup() {
    common_setup
    git config --global alias.cd "$(git config -f "$REPO/_gitconfig" alias.cd)"
    make_origin
    GCL=$REPO/_bin/git-gcl
}

# merged_on_origin <branch>: a branch with a commit that origin/master got by a merge commit,
# leaving the local master stale; back on master afterwards
merged_on_origin() {
    git switch -q -c "$1"
    commit_file "$1-file"
    git_nohooks push -q origin "$1"
    git switch -q master
    git clone -q "$T/origin.git" "$T/other" 2>/dev/null
    git -C "$T/other" -c core.hooksPath=/dev/null merge -q --no-ff -m "merge $1" "origin/$1"
    git -C "$T/other" -c core.hooksPath=/dev/null push -q origin master
}

has_branch() { git show-ref --verify --quiet "refs/heads/$1"; }

@test "a branch merged on origin by a merge commit is deleted while HEAD is elsewhere" {
    merged_on_origin done
    git switch -q -c wip
    commit_file wip-file
    run "$GCL"
    assert_success
    ! has_branch done
}

@test "a branch with commits origin does not have is kept" {
    git switch -q -c wip
    commit_file wip-file
    git switch -q master
    merged_on_origin done
    run "$GCL"
    assert_success
    has_branch wip
}

@test "a branch at the tip of origin/master has no work yet and is kept" {
    merged_on_origin done
    git fetch -q
    git branch fresh origin/master
    run "$GCL"
    assert_success
    assert_output --partial "Skip branch fresh: no commits of its own"
    has_branch fresh
}

@test "-n only lists what would be deleted" {
    merged_on_origin done
    git fetch -q  # -n skips the fetch, so origin/master must already know
    git switch -q -c wip
    commit_file wip-file
    run "$GCL" -n
    assert_success
    assert_output --partial "would run: git branch -D done"
    has_branch done
}

@test "a merged branch checked out in a worktree with changes is kept" {
    merged_on_origin done
    git fetch -q
    git worktree add -q "$T/wt" done
    echo dirty > "$T/wt/untracked"
    run "$GCL"
    assert_success
    has_branch done
}
