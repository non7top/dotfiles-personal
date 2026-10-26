#!/usr/bin/env bash
# Proves the hook tests bite: applies one deliberate relaxation at a time to a scratch copy of the
# hooks and requires the matching .bats file to fail. A mutation that survives means a rule can be
# loosened without any test noticing. Run: make test-hooks-mutation
set -uo pipefail

REPO=${REPO:-/repo}
export REPO
SRC=$REPO/_git/hooks
WORK=$(mktemp -d)
survivors=0 killed=0

# mutate <name> <file under hooks> <sed expression> <bats file that must fail>
mutate() {
    local name=$1 file=$2 expr=$3 spec=$4
    rm -rf "$WORK/hooks"
    cp -a "$SRC" "$WORK/hooks"
    sed -i "$expr" "$WORK/hooks/$file"
    if diff -rq "$SRC" "$WORK/hooks" >/dev/null; then
        echo "BROKEN MUTATION (no change applied): $name"
        survivors=$((survivors + 1))
        return
    fi
    if HOOKS_SRC=$WORK/hooks bats "$REPO/tests/hooks/$spec" >/dev/null 2>&1 < /dev/null; then
        echo "SURVIVED: $name"
        survivors=$((survivors + 1))
    else
        echo "killed:   $name"
        killed=$((killed + 1))
    fi
}

CB=pre-commit.d/block-closed-pr-branch
PB=pre-push.d/block-closed-pr-push
LIB=lib/closed-pr-check.sh

mutate "commit hook: no PR check at all"            $CB  's|^closed_pr_check .*|true|'                                 block-closed-pr-branch.bats
mutate "commit hook: disabled (exits before any check)" $CB 's|^set -euo pipefail|exit 0|'       block-closed-pr-branch.bats
mutate "commit hook: remote-gone check removed"     $CB  's|== "\[gone\]"|== "[never]"|'                                block-closed-pr-branch.bats
mutate "commit hook: skip PR check for non-own upstream" $CB 's|^closed_pr_check .*|[[ "$UPSTREAM_MERGE" == "refs/heads/$CURRENT_BRANCH" ]] \&\& closed_pr_check "$CURRENT_BRANCH" Commit|' block-closed-pr-branch.bats
mutate "commit hook: default-branch skip widened"   $CB  's|"develop"|"develop" \|\| "$CURRENT_BRANCH" == "release"|;s|"\$CURRENT_BRANCH" == "develop"|"$CURRENT_BRANCH" == "develop" \|\| "$CURRENT_BRANCH" != ""|' block-closed-pr-branch.bats
mutate "lib: query open PRs instead of closed"      $LIB 's|--state closed|--state open|'                              block-closed-pr-branch.bats
mutate "lib: query all PRs (blocks open ones)"      $LIB 's|--state closed|--state all|'                               block-closed-pr-branch.bats
mutate "lib: MERGED no longer blocks"               $LIB 's/ || "\$pr_state" == "MERGED"//'                            block-closed-pr-branch.bats
mutate "lib: CLOSED no longer blocks"               $LIB 's/"\$pr_state" == "CLOSED" || //'                            block-closed-pr-branch.bats
mutate "lib: block returns success"                 $LIB 's|        return 1|        return 0|'                         block-closed-pr-branch.bats
mutate "lib: not --head branch"                     $LIB 's|--head "\$branch"|--head "x"|'                             block-closed-pr-push.bats
mutate "lib: gh failure becomes a block"            $LIB 's/ || true)/)/'                                              block-closed-pr-branch.bats
mutate "push hook: never blocks"                    $PB  's|closed_pr_check "\$branch" "Push" \|\| ret=1|true|'        block-closed-pr-push.bats
mutate "push hook: exits before checking"           $PB  's|^set -euo pipefail|exit 0|'                                block-closed-pr-push.bats
mutate "push hook: only the last ref decides"       $PB  's#closed_pr_check "\$branch" "Push" || ret=1#closed_pr_check "$branch" "Push" \&\& ret=0 || ret=1#' block-closed-pr-push.bats
mutate "push hook: deletions are blocked"           $PB  's|\[\[ "\$local_sha" =~ \^0+\$ \]\] && continue|true|'       block-closed-pr-push.bats
mutate "push hook: default branches checked"        $PB  's|\[\[ "\$branch" == "main".*|true|'                         block-closed-pr-push.bats
mutate "push hook: branch refs skip widened to tags" $PB 's|refs/heads/\*|refs/*|'                                     block-closed-pr-push.bats
mutate "push hook: non-origin skip removed"         $PB  's|^\[\[ "\${1:-}" == "origin" \]\] .*|true|'                 block-closed-pr-push.bats
mutate "pre-push dispatcher: script failure ignored" pre-push 's|"\$file" "\$@" < "\$refs" \|\| ret=1|"$file" "$@" < "$refs" \|\| true|' dispatchers.bats
mutate "pre-push dispatcher: no stdin replay to scripts" pre-push 's|"\$file" "\$@" < "\$refs"|"$file" "$@" < /dev/null|'   dispatchers.bats
mutate "pre-push dispatcher: lfs failure ignored"    pre-push 's|git lfs pre-push "\$@" < "\$refs" \|\| ret=1|git lfs pre-push "$@" < "$refs" \|\| true|' dispatchers.bats
mutate "pre-commit dispatcher: failures ignored"     pre-commit 's|        ret=1|        ret=0|'                       dispatchers.bats
mutate "commit-msg dispatcher: failures ignored"     commit-msg 's|        ret=1|        ret=0|'                       dispatchers.bats
mutate "protect-default: never blocks"               pre-commit.d/protect-default 's|    exit 1|    exit 0|'           protect-default.bats
mutate "protect-default: protects nothing"           pre-commit.d/protect-default 's|^set -e$|exit 0|'                 protect-default.bats
mutate "terraform-docs: README changes ignored"      pre-commit.d/terraform-docs 's|    exit 1|    exit 0|'              terraform-docs.bats
mutate "run-local-hook: local hook never runs"       pre-commit.d/run-local-hook 's|-e "\$PROJECT_ROOT|-e "/nonexistent/$PROJECT_ROOT|' run-local-hook.bats

echo
echo "$killed killed, $survivors survived"
[[ $survivors -eq 0 ]]
