#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

info()    { echo -e "\e[1;34m==>\e[0m $*"; }
success() { echo -e "\e[1;32m  ✓\e[0m $*"; }
die()     { echo -e "\e[1;31m  ✗\e[0m $*" >&2; exit 1; }

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
            echo -e "\e[1;32mdone\e[0m"
        else
            die "failed to add plugin ${tool}"
        fi
    fi
done < "$SCRIPT_DIR/_tool-versions"

info "Installing tools from _tool-versions..."
asdf install
. "$SCRIPT_DIR/_bashrc"
success "All tools installed"

# Install pipx tools
info "Installing pipx tools..."
while IFS= read -r pkg || [ -n "$pkg" ]; do
    [ -z "$pkg" ] && continue
    if pipx list 2>/dev/null | grep -qw "$pkg"; then
        success "${pkg} already installed"
    else
        echo -n "  installing ${pkg}... "
        pipx install "$pkg" --quiet && echo -e "\e[1;32mdone\e[0m"
    fi
done < "$SCRIPT_DIR/_pipx-tools"

# Install npm global tools
info "Installing npm global tools..."
while IFS= read -r pkg || [ -n "$pkg" ]; do
    [ -z "$pkg" ] && continue
    echo -n "  installing ${pkg}... "
    npm install -g "$pkg" --quiet && echo -e "\e[1;32mdone\e[0m"
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
