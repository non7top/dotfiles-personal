#!/usr/bin/env bash
# Read-only. For each repo path given (default: the current directory) lists what the standard
# setup in SKILL.md is missing. Exit status is 1 if any repo has a gap or an embedded credential.
set -uo pipefail

status=0
[[ $# -gt 0 ]] || set -- .

has() { git -C "$1" ls-files --error-unmatch -- "$2" >/dev/null 2>&1; }
has_any() { [[ -n $(git -C "$1" ls-files -- "$2") ]]; }

# ecosystem|tracked file pattern that implies it
ecosystems='github-actions|.github/workflows/*
docker|Dockerfile*
docker|*/Dockerfile*
npm|package.json
pip|requirements*.txt
pip|pyproject.toml
gomod|go.mod
cargo|Cargo.toml
composer|composer.json
gradle|build.gradle*
terraform|*.tf
pre-commit|.pre-commit-config.yaml'

for repo in "$@"; do
    git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "$repo: not a git repo"; status=1; continue; }
    missing=()

    for f in LICENSE SECURITY.md .pre-commit-config.yaml .github/dependabot.yml .github/repo-config.json; do
        has "$repo" "$f" || missing+=("$f")
    done
    if ! has_any "$repo" 'README*'; then missing+=("README"); fi

    releasable=0
    if has "$repo" release-please-config.json || has "$repo" .release-please-manifest.json; then
        releasable=1
        has "$repo" release-please-config.json || missing+=("release-please-config.json")
        has "$repo" .release-please-manifest.json || missing+=(".release-please-manifest.json")
        for w in release-please release-please-preview; do
            has "$repo" ".github/workflows/$w.yml" || missing+=(".github/workflows/$w.yml")
        done
    else
        missing+=("release-please (config, manifest, release-please and release-please-preview workflows)")
    fi
    for w in conventional-commits pre-commit lint; do
        has "$repo" ".github/workflows/$w.yml" || missing+=(".github/workflows/$w.yml")
    done

    if has "$repo" .github/dependabot.yml; then
        while IFS='|' read -r eco pattern; do
            has_any "$repo" "$pattern" || continue
            git -C "$repo" show "HEAD:.github/dependabot.yml" 2>/dev/null | grep -q "package-ecosystem: *[\"']\?${eco}[\"']\?\$" \
                || missing+=("dependabot ecosystem $eco")
        done <<<"$ecosystems"
        if [[ $releasable -eq 1 ]]; then
            git -C "$repo" show HEAD:release-please-config.json 2>/dev/null | grep -q '"type": *"deps"' \
                || missing+=("release-please changelog section for deps")
        fi
    fi

    cred=""
    while read -r name url; do
        [[ $url =~ ://[^/@]+@ ]] && [[ $url != *://git@* ]] && cred="$cred $name"
    done < <(git -C "$repo" remote -v | awk '$3 == "(fetch)" { print $1, $2 }')

    echo "== $repo"
    if [[ ${#missing[@]} -eq 0 && -z $cred ]]; then
        echo "  complete"
    else
        status=1
        for m in "${missing[@]}"; do echo "  missing: $m"; done
        [[ -z $cred ]] || echo "  CREDENTIAL IN REMOTE URL (remote:$cred): rotate it and run: git remote set-url <name> <url without the token>"
    fi
done
exit $status
