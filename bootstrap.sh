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

# Steps that had to be skipped. Skipping lets the rest of the script do
# what it still can, but a skip is not success: the script ends non-zero
# with an itemized what-broke/how-to-fix list, so an incomplete bootstrap
# can't masquerade as a good one and never needs log archaeology.
INCOMPLETE=()
skip() { # $1 = what was skipped/failed, $2 = how to fix it
    warn "$1"
    INCOMPLETE+=("$1"$'\n'"      fix: $2")
}

# sudo is only attempted non-interactively: proceed with it if it's
# passwordless, otherwise skip the steps that need it rather than hang
# waiting for a password (e.g. under automation).
if sudo -n true 2>/dev/null; then
    SUDO_OK=1
else
    SUDO_OK=0
    warn "sudo needs a password or is unavailable; skipping apt-get steps"
fi

# Everything we need from apt: unzip/zstd for asdf plugins whose archives
# need them (awscli and tflint unzip theirs, ollama ships a .tar.zst).
APT_PKGS=()
command -v unzip &>/dev/null || APT_PKGS+=(unzip)
command -v zstd  &>/dev/null || APT_PKGS+=(zstd)
# nodejs >= 26 dynamically links libatomic; without it every npm call fails
ldconfig -p 2>/dev/null | grep -q libatomic.so.1 || APT_PKGS+=(libatomic1)
if [ ${#APT_PKGS[@]} -eq 0 ]; then
    success "apt packages already installed (unzip, zstd)"
elif [ "$SUDO_OK" -eq 1 ]; then
    info "Installing ${APT_PKGS[*]}..."
    sudo apt-get update -qq
    sudo apt-get install -y "${APT_PKGS[@]}"
    success "${APT_PKGS[*]} installed"
else
    skip "cannot apt-get install ${APT_PKGS[*]} without sudo" \
         "run: sudo apt-get install -y ${APT_PKGS[*]}  then re-run bootstrap.sh"
fi

# Install asdf binary
if command -v asdf &>/dev/null; then
    success "asdf already installed ($(asdf version))"
else
    info "Installing asdf..."
    mkdir -p "$HOME/.local/bin"
    # Resolve the latest tag from the release-page redirect, not the
    # GitHub API: unauthenticated api.github.com is rate-limited to
    # 60 req/hr per IP and used to abort the whole bootstrap (empty
    # version -> malformed download URL) when throttled.
    ASDF_VERSION=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
        https://github.com/asdf-vm/asdf/releases/latest | sed 's|.*/tag/v||')
    [ -n "$ASDF_VERSION" ] || die "could not resolve latest asdf version
      fix: check network access to github.com, then re-run bootstrap.sh"
    case "$(uname -m)" in
        x86_64)        ASDF_ARCH=amd64 ;;
        aarch64|arm64) ASDF_ARCH=arm64 ;;
        *) die "no asdf release binary for architecture $(uname -m)
      fix: install asdf by hand, then re-run bootstrap.sh" ;;
    esac
    info "Downloading asdf v${ASDF_VERSION}..."
    curl -fsSL "https://github.com/asdf-vm/asdf/releases/download/v${ASDF_VERSION}/asdf-v${ASDF_VERSION}-linux-${ASDF_ARCH}.tar.gz" \
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
            die "failed to add plugin ${tool}
      fix: error is directly above; check the ${tool} entry in _asdf-plugin-sources and network access, then re-run bootstrap.sh"
        fi
    fi
done < "$SCRIPT_DIR/_tool-versions"

# Shims must be on PATH *before* installing: some plugins' install
# callbacks invoke tools installed just before them (helm-git runs
# `helm`), and everything after this point needs the shims anyway.
# This used to happen by sourcing _bashrc after the install -- too late
# for helm-git, and sourcing an interactive rc file under
# `set -euo pipefail` is fragile; export the one thing we need instead.
export PATH="$HOME/.local/bin:$HOME/.asdf/shims:$PATH"

# Install per tool (not one bulk `asdf install`) so a failure is
# attributed to the exact tool at the exact moment, and one bad tool
# doesn't hide which of the other 20 worked.
info "Installing tools from _tool-versions..."
ASDF_FAILED=0
while IFS=' ' read -r tool version; do
    [ -z "$tool" ] && continue
    if asdf install "$tool" "$version"; then
        success "${tool} ${version}"
    else
        skip "asdf tool FAILED: ${tool} ${version}" \
             "error is directly above this line; retry with: asdf install ${tool} ${version}"
        ASDF_FAILED=1
    fi
done < "$SCRIPT_DIR/_tool-versions"
if [ "$ASDF_FAILED" -eq 0 ]; then
    success "All tools installed"
fi

# helm plugin self-registration silently fails during asdf install (helm shim not yet active)
if command -v helm &>/dev/null; then
    for hp in helm-diff helm-git; do
        asdf plugin list 2>/dev/null | grep -q "^${hp}$" || continue
        # plugin.yaml names vary: helm-diff registers as "diff", helm-git
        # as "helm-git" -- accept either form when checking.
        short="${hp#helm-}"
        if helm plugin list 2>/dev/null | grep -qE "^(${short}|${hp})[[:space:]]"; then
            success "${hp} already registered"
            continue
        fi
        info "Registering helm plugin ${hp}..."
        helm plugin install "$(asdf where "$hp")" 2>/dev/null || \
        helm plugin install "$(asdf where "$hp")/${hp}" 2>/dev/null || true
        # registration above is best-effort two path guesses; trust only
        # what `helm plugin list` confirms
        if helm plugin list 2>/dev/null | grep -qE "^(${short}|${hp})[[:space:]]"; then
            success "${hp} registered"
        else
            skip "helm plugin ${hp} failed to register" \
                 "run without output suppression: helm plugin install \"\$(asdf where ${hp})\""
        fi
    done
else
    skip "helm not found, skipping helm plugin registration" \
         "fix the helm asdf install above, then re-run bootstrap.sh"
fi

# Install krew plugins
if command -v krew &>/dev/null; then
    info "Installing krew plugins..."
    krew update
    while IFS= read -r plugin || [ -n "$plugin" ]; do
        [ -z "$plugin" ] && continue
        if krew list 2>/dev/null | grep -qw "$plugin"; then
            success "krew plugin ${plugin} already installed"
        elif krew install "$plugin"; then
            success "krew plugin ${plugin} installed"
        else
            skip "krew plugin FAILED: ${plugin}" \
                 "error is directly above; retry with: krew install ${plugin}"
        fi
    done < "$SCRIPT_DIR/_krew-plugins"
else
    skip "krew not found, skipping krew plugins" \
         "fix the krew asdf install above, then re-run bootstrap.sh"
fi

# gh_ext_source <extension dir>: print OWNER/REPO the extension was installed from, empty if unknown
gh_ext_source() {
    local dir=$1 url
    if [ -d "$dir/.git" ]; then
        url=$(git -C "$dir" remote get-url origin 2>/dev/null) || return 0
        url=${url%.git}
        echo "${url#*github.com[:/]}"
    elif [ -f "$dir/manifest.yml" ]; then
        awk '$1 == "owner:" { o = $2 } $1 == "name:" { n = $2 } END { if (o && n) print o "/" n }' "$dir/manifest.yml"
    fi
}

# Install gh extensions
if command -v gh &>/dev/null; then
    info "Installing gh extensions..."
    while IFS= read -r ext || [ -n "$ext" ]; do
        [ -z "$ext" ] && continue
        ext_name="${ext##*/}"
        # check the extensions dir, not `gh extension list` -- the latter
        # refuses to run before `gh auth login` (e.g. on a fresh machine)
        ext_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gh/extensions/${ext_name}"
        installed_from=""
        [ -d "$ext_dir" ] && installed_from=$(gh_ext_source "$ext_dir")
        if [ -d "$ext_dir" ] && { [ -z "$installed_from" ] || [ "${installed_from,,}" = "${ext,,}" ]; }; then
            success "gh extension ${ext_name} already installed"
        elif [ -d "$ext_dir" ] && ! gh extension remove "${ext_name#gh-}"; then
            skip "gh extension ${ext_name} comes from ${installed_from}, not ${ext}, and could not be removed" \
                 "run: gh extension remove ${ext_name#gh-} && gh extension install ${ext}"
        elif gh extension install "$ext"; then
            success "gh extension ${ext_name} installed from ${ext}"
        else
            skip "gh extension FAILED: ${ext}" \
                 "error is directly above; retry with: gh extension install ${ext}"
        fi
    done < "$SCRIPT_DIR/_gh-extensions"
else
    skip "gh not found, skipping gh extensions" \
         "fix the github-cli asdf install above, then re-run bootstrap.sh"
fi

# Install uv tools (each line: package name, optionally followed by uv args)
if command -v uv &>/dev/null; then
    info "Installing uv tools..."
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        pkg="${line%% *}"
        if uv tool list 2>/dev/null | grep -q "^${pkg} "; then
            success "uv tool ${pkg} already installed"
        elif uv tool install $line; then
            success "uv tool ${pkg} installed"
        else
            skip "uv tool FAILED: ${pkg}" \
                 "error is directly above; retry with: uv tool install ${line}"
        fi
    done < "$SCRIPT_DIR/_uv-tools"
else
    skip "uv not found, skipping uv tools" \
         "fix the uv asdf install above, then re-run bootstrap.sh"
fi

# Install npm global tools
if command -v npm &>/dev/null; then
    info "Installing npm global tools..."
    while IFS= read -r pkg || [ -n "$pkg" ]; do
        [ -z "$pkg" ] && continue
        if npm install -g "$pkg" --quiet; then
            success "npm: ${pkg} installed"
        else
            skip "npm tool FAILED: ${pkg}" \
                 "error is directly above; retry with: npm install -g ${pkg}"
        fi
    done < "$SCRIPT_DIR/_npm-global-tools"
else
    skip "npm not found, skipping npm global tools" \
         "fix the nodejs asdf install above, then re-run bootstrap.sh"
fi

# Install vim-plug
if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
    success "vim-plug already installed"
else
    info "Installing vim-plug..."
    curl -fsSLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    success "vim-plug installed"
fi

# session-manager-plugin: `aws ssm start-session` shells out to it, and
# there is no asdf plugin. Extracting the .deb needs no sudo, unlike dpkg -i.
# Tracks "latest" like asdf/vim-plug above; amd64 only like the asdf step.
if command -v session-manager-plugin &>/dev/null; then
    success "session-manager-plugin already installed"
else
    info "Installing session-manager-plugin..."
    SMP_TMP=$(mktemp -d)
    mkdir -p "$HOME/.local/bin"
    if curl -fsSL -o "$SMP_TMP/smp.deb" \
            https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb \
        && dpkg-deb -x "$SMP_TMP/smp.deb" "$SMP_TMP/x" \
        && install -m 0755 "$SMP_TMP/x/usr/local/sessionmanagerplugin/bin/session-manager-plugin" \
            "$HOME/.local/bin/session-manager-plugin"; then
        success "session-manager-plugin installed"
    else
        skip "session-manager-plugin install failed (aws ssm start-session needs it)" \
             "download session-manager-plugin.deb (ubuntu_64bit) from s3.amazonaws.com/session-manager-downloads/plugin/latest, dpkg-deb -x it, install the binary into ~/.local/bin"
    fi
    rm -rf "$SMP_TMP"
fi

# Sync dotfiles (skip in CI -- runner already has ~/.bashrc etc.)
if ! command -v dotfiles &>/dev/null; then
    skip "dotfiles command not available, skipping sync" \
         "needs the uv tools step above to succeed; re-run bootstrap.sh once uv is installed"
elif [ -z "${CI:-}" ]; then
    info "Backing up existing dotfiles..."
    for f in "$SCRIPT_DIR"/_*; do
        target="$HOME/.$(basename "$f" | sed 's/^_//')"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            mv "$target" "${target}.bak"
            echo "  backed up $(basename "$target") -> $(basename "$target").bak"
        fi
    done

    # Without ~/.dotfilesrc, dotfiles(1) falls back to defaults (no
    # prefix, no packages, repo hardcoded to ~/Dotfiles) and would sync
    # wrong targets on a fresh machine; pin both config and repo location.
    ln -sf "$SCRIPT_DIR/.dotfilesrc" "$HOME/.dotfilesrc"

    info "Syncing dotfiles..."
    if dotfiles -R "$SCRIPT_DIR" --sync; then
        success "Dotfiles synced"
    else
        skip "dotfiles sync failed" \
             "error is directly above; retry with: dotfiles -R ${SCRIPT_DIR} --sync"
    fi
fi

echo ""
if [ ${#INCOMPLETE[@]} -gt 0 ]; then
    echo -e "${RED}  ✗ Bootstrap INCOMPLETE -- ${#INCOMPLETE[@]} problem(s):${RESET}" >&2
    for item in "${INCOMPLETE[@]}"; do
        echo -e "${RED}    - ${item}${RESET}" >&2
    done
    exit 1
fi
success "Bootstrap complete!"
