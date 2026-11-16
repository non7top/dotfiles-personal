#!/usr/bin/env bash
# Read-only survey of a git repo: working tree, branches, stashes, worktrees,
# remote state. The only write is `git fetch --prune`, which updates
# remote-tracking refs and nothing else. Usage: survey.sh [repo-dir]
set -u

cd "${1:-.}" || exit 1
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "not a git repository"; exit 1; }
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT" || exit 1
GITDIR=$(git rev-parse --git-dir)

sec() { printf '\n== %s ==\n' "$1"; }

sec "FETCH"
if [ -n "$(git remote)" ]; then
  git fetch --all --prune --quiet 2>&1 && echo "fetched: $(date -u +%Y-%m-%dT%H:%MZ)"
else
  echo "no remotes configured"
fi

DEFAULT=""
if ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); then
  DEFAULT=${ref#origin/}
fi
if [ -z "$DEFAULT" ]; then
  for c in master main trunk develop; do
    if git show-ref --verify --quiet "refs/remotes/origin/$c" || git show-ref --verify --quiet "refs/heads/$c"; then
      DEFAULT=$c
      break
    fi
  done
fi
if git show-ref --verify --quiet "refs/remotes/origin/$DEFAULT"; then
  BASE="origin/$DEFAULT"
else
  BASE="$DEFAULT"
fi

HAVE_GH=0
if command -v gh >/dev/null 2>&1 && gh repo view >/dev/null 2>&1; then HAVE_GH=1; fi

sec "REPO"
echo "root:    $ROOT"
echo "remotes:"
git remote -v | sed 's/^/  /'
echo "default: ${DEFAULT:-unknown} (compare base: $BASE)"
echo "current: $(git branch --show-current) @ $(git rev-parse --short HEAD 2>/dev/null)"
if [ "$HAVE_GH" = 1 ]; then
  echo "github:  $(gh repo view --json nameWithOwner,visibility --jq '.nameWithOwner + " (" + .visibility + ")"')"
else
  echo "github:  gh unavailable or repo not on GitHub; PR checks skipped"
fi

sec "IN-PROGRESS OPERATIONS"
found=0
for f in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG; do
  if [ -e "$GITDIR/$f" ]; then echo "$f present"; found=1; fi
done
[ "$found" = 0 ] && echo "none"

sec "WORKING TREE (this checkout)"
git status --short --branch
echo "-- diffstat (staged + unstaged vs HEAD) --"
git diff HEAD --stat

sec "BRANCHES (local)"
printf '%-38s %-8s %-10s %-10s %s\n' "branch" "vs-up" "vs-base" "merged" "last-commit"
git for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)|%(committerdate:short)|%(subject)' refs/heads |
while IFS='|' read -r br up track date subj; do
  if [ -n "$up" ]; then
    case "$track" in
      "") vsup="synced" ;;
      "[gone]") vsup="GONE" ;;
      *) vsup=$(printf '%s' "$track" | tr -d '[]' | sed 's/ahead /+/; s/behind /-/; s/, /,/') ;;
    esac
  else
    vsup="no-up"
  fi
  if [ -n "$DEFAULT" ] && git rev-parse --verify --quiet "$BASE" >/dev/null; then
    read -r behind ahead < <(git rev-list --left-right --count "$BASE...$br")
    vsbase="+$ahead/-$behind"
    if [ "$ahead" = 0 ]; then
      merged="yes(anc)"
    elif ! git cherry "$BASE" "$br" 2>/dev/null | grep -q '^+'; then
      merged="yes(patch)"
    else
      merged="no"
    fi
  else
    vsbase="?"; merged="?"
  fi
  printf '%-38s %-8s %-10s %-10s %s %s\n' "$br" "$vsup" "$vsbase" "$merged" "$date" "$subj"
done
echo "(vs-base is +commits-ahead/-commits-behind; merged=yes(patch) means every commit has a patch-equivalent on base; squash merges need the PR check below)"

sec "BRANCHES (remote, not merged into base, no local branch of the same name)"
git for-each-ref --format='%(refname:short)|%(committerdate:short)|%(authorname)|%(subject)' refs/remotes |
while IFS='|' read -r rb date author subj; do
  case "$rb" in */HEAD) continue ;; esac
  short=${rb#*/}
  [ "$rb" = "$BASE" ] && continue
  git show-ref --verify --quiet "refs/heads/$short" && continue
  if git merge-base --is-ancestor "$rb" "$BASE" 2>/dev/null; then continue; fi
  read -r behind ahead < <(git rev-list --left-right --count "$BASE...$rb")
  printf '%-40s +%s/-%s %s %s %s\n' "$rb" "$ahead" "$behind" "$date" "$author" "$subj"
done

sec "STASHES"
if [ -z "$(git stash list)" ]; then
  echo "none"
else
  git stash list --format='%gd | %cs | %gs'
  echo
  git stash list --format='%gd' | while read -r s; do
    echo "-- $s --"
    git stash show --stat "$s"
    untracked=$(git ls-tree -r --name-only "$s^3" 2>/dev/null)
    [ -n "$untracked" ] && { echo "untracked files in stash:"; echo "$untracked" | sed 's/^/  /'; }
  done
fi

sec "WORKTREES"
git worktree list --porcelain | awk -v RS= -F'\n' '{print $0 "\n"}' | sed 's/^/  /'
echo "-- state per worktree --"
git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | while read -r wt; do
  if [ -d "$wt" ]; then
    dirty=$(git -C "$wt" status --short | wc -l)
    br=$(git -C "$wt" branch --show-current)
    echo "$wt  branch=${br:-detached}  dirty-files=$dirty"
  else
    echo "$wt  MISSING on disk (prunable)"
  fi
done
echo "-- prune dry run --"
git worktree prune --dry-run --verbose
echo "-- other worktree dirs not registered --"
for d in "$ROOT"/.worktrees "$ROOT"/../"$(basename "$ROOT")"-wt* ; do
  [ -d "$d" ] && echo "candidate: $d"
done

sec "COMMITS NOT ON ANY REMOTE (local-only work)"
if [ -n "$(git remote)" ]; then
  git log --branches --not --remotes --oneline --decorate --date=short --format='%h %ad %d %s' | head -n 60
else
  echo "no remotes"
fi

sec "WIP-STYLE COMMITS ON LOCAL BRANCHES AHEAD OF BASE"
git log --branches --not "$BASE" -i --grep='^\(wip\|fixup!\|squash!\|tmp\|todo\)' --format='%h %s' | head -n 30

if [ "$HAVE_GH" = 1 ]; then
  sec "OPEN PRs (all authors)"
  gh pr list --state open --limit 50 \
    --json number,title,headRefName,baseRefName,isDraft,author,reviewDecision,mergeStateStatus,statusCheckRollup \
    --jq '.[] | "#\(.number) \(.headRefName) -> \(.baseRefName) draft=\(.isDraft) by=\(.author.login) review=\(.reviewDecision) merge=\(.mergeStateStatus) checks=\([.statusCheckRollup[]? | .conclusion // .state] | group_by(.) | map("\(.[0])x\(length)") | join(","))  \(.title)"'

  sec "PR STATE PER LOCAL BRANCH (catches squash merges)"
  git for-each-ref --format='%(refname:short)' refs/heads | while read -r br; do
    [ "$br" = "$DEFAULT" ] && continue
    out=$(gh pr list --state all --head "$br" --limit 3 --json number,state,mergedAt,title \
      --jq '.[] | "#\(.number) \(.state) \(.mergedAt // "")  \(.title)"')
    printf '%-38s %s\n' "$br" "${out:-no PR}"
  done
fi

sec "UNTRACKED FILES (not ignored)"
git ls-files --others --exclude-standard | head -n 50
echo "(capped at 50; count: $(git ls-files --others --exclude-standard | wc -l))"
