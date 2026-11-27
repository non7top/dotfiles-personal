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

@test "a branch whose non-merge commits landed individually on origin/master is deleted" {
    git switch -q -c feat-cherry
    commit_file cherry-1
    commit_file cherry-2
    git_nohooks push -q origin feat-cherry
    git switch -q master
    commit_file master-advance
    git_nohooks push -q origin master
    git clone -q "$T/origin.git" "$T/other" 2>/dev/null
    git -C "$T/other" -c core.hooksPath=/dev/null cherry-pick "$(git rev-parse feat-cherry~1)" "$(git rev-parse feat-cherry)"
    git -C "$T/other" -c core.hooksPath=/dev/null push -q origin master
    git switch -q -c wip
    commit_file wip-file
    run env NO_COLOR=1 "$GCL"
    assert_success
    ! has_branch feat-cherry
}

@test "an unmerged branch is skipped with ahead/behind and unapplied commit count" {
    git switch -q -c unmerged-br
    commit_file unmerged-file
    git switch -q master
    commit_file master-advance
    git_nohooks push -q origin master
    run "$GCL"
    assert_success
    assert_output --partial "Skip branch unmerged-br: not merged (ahead 1, behind 1; 1 unapplied)"
    has_branch unmerged-br
}

@test "a branch merged into another remote branch reports merged into origin/<other>" {
    git switch -q -c staging
    commit_file staging-file
    git_nohooks push -q -u origin staging
    git switch -q -c topic staging
    commit_file topic-file
    git_nohooks push -q -u origin topic
    git clone -q "$T/origin.git" "$T/other" 2>/dev/null
    git -C "$T/other" -c core.hooksPath=/dev/null checkout -q staging
    git -C "$T/other" -c core.hooksPath=/dev/null merge -q --no-ff -m "merge topic" origin/topic
    git -C "$T/other" -c core.hooksPath=/dev/null push -q origin staging
    git switch -q master
    run "$GCL"
    assert_success
    assert_output --partial "Skip branch topic: merged into origin/staging"
    has_branch topic
}

@test "leftover stashes report fully merged, partially merged, and unmerged stashes" {
    git switch -q -c stash-branch
    commit_file merged-file "merged-content"
    git reset -q HEAD~1
    git_nohooks add merged-file
    git_nohooks stash push -m "WIP on stash-branch: stash with merged content" merged-file
    git switch -q master
    commit_file merged-file "merged-content"
    git_nohooks push -q origin master
    git switch -q -c unmerged-stash-branch
    echo "unmerged-content" > unmerged-file
    git_nohooks add unmerged-file
    git_nohooks stash push -m "WIP on unmerged-stash-branch: unmerged stash" unmerged-file
    git switch -q master
    git branch -D unmerged-stash-branch stash-branch
    run env NO_COLOR=1 "$GCL"
    assert_success
    assert_output --partial "Start checking leftover stashes"
    assert_output --partial "stash@{1}"
    assert_output --partial "fully merged (all 1 files in origin/master)"
    assert_output --partial "drop with: git stash drop stash@{1}"
    assert_output --partial "stash@{0}"
    assert_output --partial "on unmerged-stash-branch (branch gone)): not merged"
    assert_output --partial "Finish checking leftover stashes"
}
