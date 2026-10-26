#!/usr/bin/env bash
# Scenarios for the closed/merged-PR hooks (pre-commit.d/block-closed-pr-branch and
# pre-push.d/block-closed-pr-push). Runs in the disposable test container (make test-hooks):
# scratch repos with a local bare remote, and gh/git-lfs stubs, so no network or credentials.
#
# Contract under test: nothing may land on a branch whose PR is closed/merged. Cases the commit
# hook allows (new branch cut from a merged one) must be caught by the push hook.
set -uo pipefail

REPO=${REPO:-/repo}
HOOKS=$REPO/_git/hooks
WORK=$(mktemp -d)
MERGED=merged-br

export GIT_CONFIG_GLOBAL=$WORK/gitconfig GIT_CONFIG_NOSYSTEM=1
git config --global user.email t@example.com
git config --global user.name t
git config --global init.defaultBranch master

# gh stub: authenticated, and `pr list --head X` reports MERGED only for $MERGED
mkdir "$WORK/bin"
cat > "$WORK/bin/gh" <<EOF
#!/bin/sh
[ "\$1 \$2" = "auth status" ] && exit \${GH_STUB_AUTH:-0}
if [ "\$1 \$2" = "pr list" ]; then
    [ "\$4" = "$MERGED" ] && echo MERGED
    exit 0
fi
exit 1
EOF
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/git-lfs"
chmod +x "$WORK/bin/gh" "$WORK/bin/git-lfs"
export PATH=$WORK/bin:$PATH

pass=0 fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; echo "$OUT" | sed 's/^/      /'; fail=$((fail + 1)); }

# expect <rc> <name> <grep pattern or ""> <cmd...>: run in the current repo, check rc and output
expect() {
    local want=$1 name=$2 pattern=$3
    shift 3
    OUT=$("$@" 2>&1)
    local rc=$?
    if [[ $rc -eq $want ]] && { [[ -z "$pattern" ]] || grep -q -- "$pattern" <<<"$OUT"; }; then
        ok "$name"
    else
        bad "$name (rc=$rc, want $want)"
    fi
}

nohooks() { git -c core.hooksPath=/dev/null "$@"; }

# fresh clone with master and a pushed $MERGED branch; hooks installed as core.hooksPath
setup() {
    local d
    d=$(mktemp -d -p "$WORK")
    git init -q --bare "$d/origin.git"
    git clone -q "$d/origin.git" "$d/repo" 2>/dev/null
    cd "$d/repo" || exit 1
    echo a > f && git add f && nohooks commit -qm init && nohooks push -q origin master
    git switch -q -c "$MERGED"
    echo m > m && git add m && nohooks commit -qm m && nohooks push -q -u origin "$MERGED"
    git switch -q master
    cp -r "$HOOKS" "$d/hooks"
    git config core.hooksPath "$d/hooks"
}

commit_hook() { "$HOOKS/pre-commit.d/block-closed-pr-branch"; }

echo "== commit hook: valid commits must not be blocked"
setup
git switch -q -c feature origin/master
expect 0 "new branch cut from origin/master, never pushed (checkout -b/switch -c)" "" commit_hook
git switch -q master
git worktree add -q -b wt-feature "$WORK/wt" origin/master
cd "$WORK/wt" && expect 0 "new worktree branch cut from origin/master" "" commit_hook
cd - >/dev/null
git switch -q -c nouplink --no-track
expect 0 "branch with no upstream" "" commit_hook
git switch -q -c from-merged "origin/$MERGED"
expect 0 "new name cut from origin/<merged branch>" "" commit_hook
git switch -q master
expect 0 "master" "" commit_hook
git switch -q -c pushed-ok
git push -q -u origin pushed-ok
expect 0 "pushed with -u, remote present, no PR" "" commit_hook

echo "== commit hook: closed/merged PR and missing remote must stay blocked"
setup
git switch -q "$MERGED"
expect 1 "the merged branch itself, remote present" "MERGED pull request" commit_hook
git push -q origin --delete "$MERGED"
expect 1 "the merged branch itself, remote deleted" "git push -u origin $MERGED" commit_hook
git switch -q master
git branch -q -D "$MERGED"
git switch -q -c "$MERGED" origin/master
expect 1 "merged branch's name reused, cut from origin/master" "MERGED pull request" commit_hook
git switch -q -c never-pushed
git config branch.never-pushed.remote origin
git config branch.never-pushed.merge refs/heads/never-pushed
expect 1 "upstream origin/<self> configured but never pushed: says to create it" "git push -u origin never-pushed" commit_hook

echo "== commit hook: gh unavailable is advisory"
setup
git switch -q "$MERGED"
GH_STUB_AUTH=1 expect 0 "unauthenticated gh warns and allows" "not authenticated" commit_hook

echo "== push hook (via the pre-push dispatcher): the way onto a merged branch is closed"
setup
git switch -q -c from-merged "origin/$MERGED"
echo n > n && git add n && nohooks commit -qm n
before=$(git rev-parse "origin/$MERGED")
expect 1 "git push origin <local>:<merged>" "Push blocked" git push origin "from-merged:$MERGED"
expect 1 "git push origin HEAD:<merged>" "Push blocked" git push origin "HEAD:$MERGED"
expect 1 "git push --force origin <local>:<merged>" "Push blocked" git push --force origin "from-merged:$MERGED"
expect 1 "push.default=upstream, plain git push" "Push blocked" git -c push.default=upstream push
git fetch -q origin
if [[ "$(git rev-parse "origin/$MERGED")" == "$before" ]]; then
    ok "merged remote branch unchanged after blocked pushes"
else
    OUT=""; bad "merged remote branch moved"
fi

echo "== push hook: valid pushes must not be blocked"
expect 0 "push under a fresh branch name" "" git push origin from-merged:fresh-name
expect 0 "delete a remote branch" "" git push origin --delete fresh-name
expect 0 "delete the merged remote branch (cleanup)" "" git push origin --delete "$MERGED"
expect 0 "push to master" "" git push origin from-merged:master

echo "== push hook: known gap, only origin is checked"
expect 0 "push to a non-origin remote is not checked" "" bash -c "
    git init -q --bare '$WORK/other.git' && git remote add other '$WORK/other.git' &&
    git push other from-merged:$MERGED"

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
