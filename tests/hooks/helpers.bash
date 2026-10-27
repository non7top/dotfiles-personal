# Shared helpers for the git hook tests (bats). `load helpers` in a .bats file, then call
# common_setup from setup(). Run through `make test-hooks`: the tests expect the container's PATH
# (no real gh or git-lfs) and write only under $BATS_TEST_TMPDIR.
#
# Every test gets its own world: scratch HOME and git config, a copy of the hooks, its own stub
# binaries first on PATH (tests/hooks/stubs), and its own gh state (PRs, auth, failures). The stub
# code is shared; the scenario is declared per test with the gh_stub_* functions.
#
# HOOKS_SRC points the suite at another hooks tree, to check that the tests fail on old/mutated hooks.

REPO=${REPO:-$(cd "$BATS_TEST_DIRNAME/../.." && pwd)}
HOOKS_SRC=${HOOKS_SRC:-$REPO/_git/hooks}
MERGED_BR=merged-br

common_setup() {
    export BATS_LIB_PATH=/usr/lib/bats${BATS_LIB_PATH:+:$BATS_LIB_PATH}
    bats_load_library bats-support
    bats_load_library bats-assert

    T=$BATS_TEST_TMPDIR
    export HOME=$T/home STUB_LOG_DIR=$T/stub-logs GH_STUB_DIR=$T/gh
    mkdir -p "$HOME" "$STUB_LOG_DIR" "$GH_STUB_DIR" "$T/bin"
    echo '[]' > "$GH_STUB_DIR/prs.json"
    cp "$REPO"/tests/hooks/stubs/* "$T/bin/"
    export PATH="$T/bin:/usr/local/bin:/usr/bin:/bin"

    export GIT_CONFIG_GLOBAL=$T/gitconfig GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
    git config --global user.email t@example.com
    git config --global user.name t
    git config --global init.defaultBranch master
    # the real alias, so protect-default follows the repo's definition of `git sd`
    git config --global alias.sd "$(git config -f "$REPO/_gitconfig" alias.sd)"

    cp -a "$HOOKS_SRC" "$T/hooks"
    HOOKS=$T/hooks
}

# -- gh scenario ------------------------------------------------------------------------------

# gh_stub_pr <head branch> <OPEN|CLOSED|MERGED> [number]: a PR exists for that head branch
gh_stub_pr() {
    local n=${3:-$(( $(jq length "$GH_STUB_DIR/prs.json") + 1 ))}
    jq --arg h "$1" --arg s "$2" --argjson n "$n" \
        '. + [{number: $n, headRefName: $h, state: $s}]' \
        "$GH_STUB_DIR/prs.json" > "$GH_STUB_DIR/prs.tmp"
    mv "$GH_STUB_DIR/prs.tmp" "$GH_STUB_DIR/prs.json"
}
gh_stub_auth_rc()    { echo "$1" > "$GH_STUB_DIR/auth_rc"; }
gh_stub_pr_list_rc() { echo "$1" > "$GH_STUB_DIR/pr_list_rc"; }
gh_stub_absent()     { rm -f "$T/bin/gh"; }

gh_calls() { cat "$STUB_LOG_DIR/gh.log" 2>/dev/null || true; }

assert_gh_not_called() {
    [[ ! -s "$STUB_LOG_DIR/gh.log" ]] || { echo "gh was called:"; gh_calls; return 1; }
}

# assert_gh_queried_closed_prs <head>: the hook asked for CLOSED/MERGED PRs of exactly that head
assert_gh_queried_closed_prs() {
    local line
    line=$(gh_calls | grep -F "pr list" | grep -F -- "--head $1 " || true)
    [[ -n "$line" && "$line" == *"--state closed"* ]] || { echo "no 'pr list --head $1 --state closed' in:"; gh_calls; return 1; }
}

# -- other stubs ------------------------------------------------------------------------------

stub_calls() { cat "$STUB_LOG_DIR/$1.log" 2>/dev/null || true; }

# -- git scratch repos ------------------------------------------------------------------------

git_nohooks() { git -c core.hooksPath=/dev/null "$@"; }

# commit_file <path> [content]: write, stage and commit without hooks
commit_file() {
    mkdir -p "$(dirname "$1")"
    echo "${2:-$1}" > "$1"
    git add "$1"
    git_nohooks commit -qm "add $1"
}

# make_origin: bare origin with master, a clone of it at $T/repo (cwd), origin/HEAD set
make_origin() {
    git init -q --bare "$T/origin.git"
    git clone -q "$T/origin.git" "$T/repo" 2>/dev/null
    cd "$T/repo" || return 1
    commit_file README
    git_nohooks push -q origin master
    git remote set-head origin master >/dev/null
}

# make_merged_branch: $MERGED_BR pushed to origin with -u and a MERGED PR for it; back on master
make_merged_branch() {
    git switch -q -c "$MERGED_BR"
    commit_file merged-file
    git_nohooks push -q -u origin "$MERGED_BR"
    git switch -q master
    gh_stub_pr "$MERGED_BR" MERGED
}

# use_hooks_path: make real git run the (copied) hooks in the current repo
use_hooks_path() { git config core.hooksPath "$HOOKS"; }
