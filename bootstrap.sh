#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install pipx
if ! command -v pipx &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y pipx
fi

# Install asdf binary
if ! command -v asdf &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ASDF_VERSION=$(curl -fsSL https://api.github.com/repos/asdf-vm/asdf/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4 | tr -d 'v')
    curl -fsSL "https://github.com/asdf-vm/asdf/releases/download/v${ASDF_VERSION}/asdf_${ASDF_VERSION}_linux_amd64.tar.gz" \
        | tar -xz -C "$HOME/.local/bin" asdf
    export PATH="$HOME/.local/bin:$PATH"
fi

# Add plugins and install tools from _tool-versions
while IFS=' ' read -r tool _version; do
    asdf plugin add "$tool" 2>/dev/null || true
done < "$SCRIPT_DIR/_tool-versions"

asdf install --file "$SCRIPT_DIR/_tool-versions"

# Install pipx tools
pipx install dotfiles
pipx install pre-commit

# Sync dotfiles
cd "$SCRIPT_DIR"
dotfiles --sync
