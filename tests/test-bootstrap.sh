#!/usr/bin/env bash
# Fresh-machine bootstrap test: run bootstrap.sh exactly as the README
# quick-start does, then verify every thing it promises to install —
# regardless of whether the script itself exited 0. Runs inside the
# disposable bootstrap container (make test-bootstrap).
set -uo pipefail

REPO=${REPO:-/repo}
pass=0 fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

echo "== running bootstrap.sh"
# Run from $HOME like a real user: several asdf plugins (kyverno-cli,
# ripsecrets, uv) extract/download into the current working directory,
# and /repo is mounted read-only in the test container.
cd "$HOME"
if bash "$REPO/bootstrap.sh"; then
    ok "bootstrap.sh exited 0"
else
    bad "bootstrap.sh exited non-zero — every step after the failure was skipped"
fi

# What an interactive shell would have on PATH after bootstrap
export PATH="$HOME/.local/bin:$HOME/.asdf/shims:${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

echo "== core commands"
for c in asdf dotfiles pre-commit; do
    if command -v "$c" >/dev/null 2>&1; then
        ok "$c on PATH"
    else
        bad "$c missing"
    fi
done

echo "== asdf tools from _tool-versions"
if command -v asdf >/dev/null 2>&1; then
    while IFS=' ' read -r tool version; do
        [ -z "$tool" ] && continue
        if asdf list "$tool" 2>/dev/null | grep -q "$version"; then
            ok "asdf: $tool $version"
        else
            bad "asdf: $tool $version not installed"
        fi
    done < "$REPO/_tool-versions"
else
    bad "asdf missing entirely — skipping per-tool checks"
fi

echo "== helm plugins"
if command -v helm >/dev/null 2>&1; then
    for p in diff git; do
        # helm-diff registers as "diff", helm-git as "helm-git"
        if helm plugin list 2>/dev/null | grep -qE "^(helm-)?${p}[[:space:]]"; then
            ok "helm plugin: $p"
        else
            bad "helm plugin not registered: $p"
            helm plugin list 2>&1 | sed 's/^/    | /'
        fi
    done
else
    bad "helm not on PATH — plugin registration silently skipped"
fi

echo "== krew plugins"
if command -v kubectl-krew >/dev/null 2>&1 || command -v krew >/dev/null 2>&1; then
    while IFS= read -r plugin || [ -n "$plugin" ]; do
        [ -z "$plugin" ] && continue
        if krew list 2>/dev/null | grep -qw "$plugin"; then
            ok "krew plugin: $plugin"
        else
            bad "krew plugin missing: $plugin"
        fi
    done < "$REPO/_krew-plugins"
else
    bad "krew not on PATH — krew plugins silently skipped"
fi

echo "== gh extensions"
if command -v gh >/dev/null 2>&1; then
    while IFS= read -r ext || [ -n "$ext" ]; do
        [ -z "$ext" ] && continue
        # dir check, not `gh extension list`: the CLI refuses to list
        # extensions before `gh auth login`
        if [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/gh/extensions/${ext##*/}" ]; then
            ok "gh extension: $ext"
        else
            bad "gh extension missing: $ext"
            ls "${XDG_DATA_HOME:-$HOME/.local/share}/gh/extensions/" 2>&1 | sed 's/^/    | /'
        fi
    done < "$REPO/_gh-extensions"
else
    bad "gh not on PATH — gh extensions silently skipped"
fi

echo "== pipx tools"
while IFS= read -r pkg || [ -n "$pkg" ]; do
    [ -z "$pkg" ] && continue
    if command -v pipx >/dev/null 2>&1 && pipx list 2>/dev/null | grep -qw "$pkg"; then
        ok "pipx: $pkg"
    else
        bad "pipx tool missing: $pkg"
    fi
done < "$REPO/_pipx-tools"

echo "== npm global tools"
if command -v npm >/dev/null 2>&1; then
    while IFS= read -r pkg || [ -n "$pkg" ]; do
        [ -z "$pkg" ] && continue
        if npm ls -g --depth=0 2>/dev/null | grep -q "$pkg"; then
            ok "npm: $pkg"
        else
            bad "npm tool missing: $pkg"
        fi
    done < "$REPO/_npm-global-tools"
else
    bad "npm not on PATH (nodejs asdf install failed?) — npm step would have aborted the script"
fi

echo "== vim-plug"
if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
    ok "vim-plug installed"
else
    bad "vim-plug missing"
fi

echo "== dotfiles sync results (the 'claude and other stuff')"
for link in .bashrc .vimrc .claude/skills .claude/statusline-command.sh .gemini/statusline-command.sh; do
    if [ -L "$HOME/$link" ]; then
        ok "synced: ~/$link"
    else
        bad "not synced: ~/$link"
    fi
done

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
