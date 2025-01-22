#!/usr/bin/env bash

# Exit immediately on error, unset variables, and pipeline failure
set -euo pipefail

# Detect operating system
OS="$(uname -s)"
case "$OS" in
    Linux*)     PLATFORM="linux";;
    Darwin*)    PLATFORM="macos";;
    *)          echo "Unsupported OS: $OS"; exit 1;;
esac

# Package manager configuration
if [[ "$PLATFORM" == "linux" ]]; then
    PKG_UPDATE="sudo apt-get update -qq"
    PKG_INSTALL="sudo apt-get install -y -qq"
    ZSH_PACKAGE="zsh"
elif [[ "$PLATFORM" == "macos" ]]; then
    # Check for Homebrew
    if ! command -v brew >/dev/null; then
        echo "Homebrew required but not found. Please install first:"
        echo "https://brew.sh/"
        exit 1
    fi
    PKG_UPDATE="brew update -q"
    PKG_INSTALL="brew install -q"
    ZSH_PACKAGE="zsh"
fi

# Required command-line tools
REQUIRED_CMDS=(curl git)
MISSING_CMDS=()
for cmd in "${REQUIRED_CMDS[@]}"; do
    command -v "$cmd" >/dev/null || MISSING_CMDS+=("$cmd")
done

# Install missing dependencies
if [[ ${#MISSING_CMDS[@]} -gt 0 ]]; then
    echo "Installing missing dependencies: ${MISSING_CMDS[*]}..."
    $PKG_UPDATE
    $PKG_INSTALL "${MISSING_CMDS[@]}"
fi

# Install Zsh if not present
if ! command -v zsh >/dev/null; then
    echo "Installing Zsh..."
    $PKG_UPDATE
    $PKG_INSTALL "$ZSH_PACKAGE"
else
    echo "Zsh already installed at $(command -v zsh)"
fi

# Verify Zsh is in /etc/shells
ZSH_PATH="$(command -v zsh)"
if ! grep -qxF "$ZSH_PATH" /etc/shells; then
    echo "Adding $ZSH_PATH to /etc/shells..."
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

# Set default shell
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    echo "Setting Zsh as default shell..."
    sudo chsh -s "$ZSH_PATH" "$USER"
else
    echo "Zsh already set as default shell"
fi

# Install Oh My Zsh
OMZ_DIR="${HOME}/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh already installed"
fi

# Ensure .zshrc exists
ZSHRC="${HOME}/.zshrc"
if [[ ! -f "$ZSHRC" ]]; then
    echo "Creating initial .zshrc..."
    cp "$OMZ_DIR/templates/zshrc.zsh-template" "$ZSHRC"
fi

# Configure plugins
PLUGINS=(git zsh-autosuggestions colored-man-pages zsh-completions zsh-history-substring-search pass)
SYNTAX_HIGHLIGHTING="zsh-syntax-highlighting"

echo "Configuring plugins in .zshrc..."
awk -v plugins="${PLUGINS[*]}" -v syntax="$SYNTAX_HIGHLIGHTING" '
    BEGIN { updated = 0 }
    /^plugins=\(/ {
        print "plugins=(" plugins " " syntax ")";
        updated = 1;
        next
    }
    { print }
    END {
        if (!updated) print "plugins=(" plugins " " syntax ")"
    }' "$ZSHRC" > "${ZSHRC}.tmp" && mv "${ZSHRC}.tmp" "$ZSHRC"

# Plugin installation function
clone_plugin() {
    local repo="$1"
    local dest="$2"
    
    if [[ ! -d "$dest" ]]; then
        echo "Cloning $repo..."
        git clone --quiet --depth 1 "$repo" "$dest" || {
            echo "Error cloning $repo" >&2
            return 1
        }
    else
        echo "Plugin exists: $(basename "$dest")"
    fi
}

# Install plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-${OMZ_DIR}/custom}"
declare -a PLUGIN_REPOS=(
    "zsh-completions https://github.com/zsh-users/zsh-completions"
    "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git"
    "zsh-history-substring-search https://github.com/zsh-users/zsh-history-substring-search"
)

for plugin in "${PLUGIN_REPOS[@]}"; do
    name="${plugin%% *}"
    url="${plugin#* }"
    clone_plugin "$url" "${ZSH_CUSTOM}/plugins/${name}"
done

# Final setup
echo -e "\nSetup complete! Starting new Zsh session..."
exec zsh -l
