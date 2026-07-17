#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED=$'\e[1;31m'
GREEN=$'\e[1;32m'
YELLOW=$'\e[1;33m'
BLUE=$'\e[1;34m'
RESET=$'\e[0m'

info()    { echo -e "${BLUE}==>${RESET} $*"; }
success() { echo -e "${GREEN}  ✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}  !${RESET} $*" >&2; }
die()     { echo -e "${RED}  ✗${RESET} $*" >&2; exit 1; }

# Install pipx
if command -v pipx &>/dev/null; then
    success "pipx already installed"
else
    info "Installing pipx..."
    sudo apt-get update -qq
    sudo apt-get install -y pipx
    success "pipx installed"
fi

# Install asdf binary
if command -v asdf &>/dev/null; then
    success "asdf already installed ($(asdf version))"
else
    info "Installing asdf..."
    mkdir -p "$HOME/.local/bin"
    ASDF_VERSION=$(curl -fsSL https://api.github.com/repos/asdf-vm/asdf/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4 | tr -d 'v')
    info "Downloading asdf v${ASDF_VERSION}..."
    curl -fsSL "https://github.com/asdf-vm/asdf/releases/download/v${ASDF_VERSION}/asdf-v${ASDF_VERSION}-linux-amd64.tar.gz" \
        | tar -xz -C "$HOME/.local/bin" asdf
    export PATH="$HOME/.local/bin:$PATH"
    success "asdf v${ASDF_VERSION} installed"
fi

# Add plugins and install tools from _tool-versions
ln -sf "$SCRIPT_DIR/_tool-versions" "$HOME/.tool-versions"

info "Adding asdf plugins..."
while IFS=' ' read -r tool _version; do
    if asdf plugin list 2>/dev/null | grep -q "^${tool}$"; then
        success "plugin ${tool} already added"
    else
        echo -n "  adding ${tool}... "
        plugin_url=$(grep "^${tool} " "$SCRIPT_DIR/_asdf-plugin-sources" 2>/dev/null | awk '{print $2}' || true)
        if asdf plugin add "$tool" $plugin_url; then
            echo -e "${GREEN}done${RESET}"
        else
            die "failed to add plugin ${tool}"
        fi
    fi
done < "$SCRIPT_DIR/_tool-versions"

info "Installing tools from _tool-versions..."
asdf install
. "$SCRIPT_DIR/_bashrc"
success "All tools installed"

# helm plugin self-registration silently fails during asdf install (helm shim not yet active)
if command -v helm &>/dev/null; then
    for hp in helm-diff helm-git; do
        asdf plugin list 2>/dev/null | grep -q "^${hp}$" || continue
        plugin_name="${hp/helm-/}"  # helm-diff -> diff, helm-git -> git
        if ! helm plugin list 2>/dev/null | grep -q "^${plugin_name}[[:space:]]"; then
            info "Registering helm plugin ${hp}..."
            helm plugin install "$(asdf where "$hp")" 2>/dev/null || \
            helm plugin install "$(asdf where "$hp")/${hp}" 2>/dev/null || true
            success "${hp} registered"
        else
            success "${hp} already registered"
        fi
    done
else
    warn "helm not found, skipping helm plugin registration"
fi

# Install krew plugins
if command -v krew &>/dev/null; then
    info "Installing krew plugins..."
    krew update
    while IFS= read -r plugin || [ -n "$plugin" ]; do
        [ -z "$plugin" ] && continue
        if krew list 2>/dev/null | grep -qw "$plugin"; then
            success "krew plugin ${plugin} already installed"
        else
            echo -n "  installing ${plugin}... "
            krew install "$plugin" && echo -e "${GREEN}done${RESET}"
        fi
    done < "$SCRIPT_DIR/_krew-plugins"
else
    warn "krew not found, skipping krew plugins"
fi

# Install gh extensions
if command -v gh &>/dev/null; then
    info "Installing gh extensions..."
    while IFS= read -r ext || [ -n "$ext" ]; do
        [ -z "$ext" ] && continue
        ext_name="${ext##*/}"
        if gh extension list 2>/dev/null | grep -qw "$ext_name"; then
            success "gh extension ${ext_name} already installed"
        else
            echo -n "  installing ${ext}... "
            gh extension install "$ext" && echo -e "${GREEN}done${RESET}"
        fi
    done < "$SCRIPT_DIR/_gh-extensions"
else
    warn "gh not found, skipping gh extensions"
fi

# Install pipx tools
info "Installing pipx tools..."
while IFS= read -r pkg || [ -n "$pkg" ]; do
    [ -z "$pkg" ] && continue
    if pipx list 2>/dev/null | grep -qw "$pkg"; then
        success "${pkg} already installed"
    else
        echo -n "  installing ${pkg}... "
        pipx install "$pkg" --quiet && echo -e "${GREEN}done${RESET}"
    fi
done < "$SCRIPT_DIR/_pipx-tools"

# Install `dotfiles` from our fork (upstream PyPI has an unfixed
# prefix-stripping bug -- see non7top/dotfiles-personal#24). Always
# force-reinstall so a previously PyPI-installed copy gets replaced;
# --force is fast/idempotent so this is safe on every run.
info "Installing dotfiles (patched fork)..."
pipx install --force "git+https://github.com/non7top/dotfiles.git" --quiet
success "dotfiles installed from non7top/dotfiles@main"

# Install npm global tools
info "Installing npm global tools..."
while IFS= read -r pkg || [ -n "$pkg" ]; do
    [ -z "$pkg" ] && continue
    echo -n "  installing ${pkg}... "
    npm install -g "$pkg" --quiet && echo -e "${GREEN}done${RESET}"
done < "$SCRIPT_DIR/_npm-global-tools"

# Install vim-plug
if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
    success "vim-plug already installed"
else
    info "Installing vim-plug..."
    curl -fsSLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    success "vim-plug installed"
fi

# Sync dotfiles (skip in CI — runner already has ~/.bashrc etc.)
if [ -z "${CI:-}" ]; then
    info "Backing up existing dotfiles..."
    for f in "$SCRIPT_DIR"/_*; do
        target="$HOME/.$(basename "$f" | sed 's/^_//')"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            mv "$target" "${target}.bak"
            echo "  backed up $(basename "$target") -> $(basename "$target").bak"
        fi
    done

    info "Syncing dotfiles..."
    dotfiles --sync
    success "Dotfiles synced"
fi

echo ""
success "Bootstrap complete!"
