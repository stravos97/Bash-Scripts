#!/usr/bin/env bash

# Exit immediately on error, unset variables, and pipeline failure
set -euo pipefail

# Script variables
SCRIPT_NAME=$(basename "$0")
ZSH_THEME="fox"
BACKUP_SUFFIX=".backup-$(date +%Y%m%d-%H%M%S)"
VERBOSE=1

# Color codes for better readability
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Helper functions
log() { 
    [[ $VERBOSE -eq 1 ]] && echo -e "${BLUE}[INFO]${RESET} $*"
}

success() { 
    echo -e "${GREEN}[SUCCESS]${RESET} $*"
}

warn() { 
    echo -e "${YELLOW}[WARNING]${RESET} $*" >&2
}

error() { 
    echo -e "${RED}[ERROR]${RESET} $*" >&2
    exit 1
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}${BACKUP_SUFFIX}"
        log "Creating backup of $file to $backup"
        cp "$file" "$backup" || error "Failed to create backup of $file"
    fi
}

# Detect operating system
log "Detecting operating system..."
OS="$(uname -s)"
case "$OS" in
    Linux*)     
        PLATFORM="linux"
        log "Detected Linux operating system"
        ;;
    Darwin*)    
        PLATFORM="macos"
        log "Detected macOS operating system"
        ;;
    *)          
        error "Unsupported OS: $OS"
        ;;
esac

# Package manager configuration
if [[ "$PLATFORM" == "linux" ]]; then
    PKG_UPDATE="sudo apt-get update -qq"
    PKG_INSTALL="sudo apt-get install -y -qq"
    ZSH_PACKAGE="zsh"
elif [[ "$PLATFORM" == "macos" ]]; then
    # Check for Homebrew
    if ! command -v brew >/dev/null; then
        error "Homebrew required but not found. Please install first:\nhttps://brew.sh/"
    fi
    PKG_UPDATE="brew update -q"
    PKG_INSTALL="brew install -q"
    ZSH_PACKAGE="zsh"
fi

# Required command-line tools
log "Checking required dependencies..."
REQUIRED_CMDS=(curl git)
MISSING_CMDS=()
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null; then
        MISSING_CMDS+=("$cmd")
        warn "Missing required command: $cmd"
    fi
done

# Install missing dependencies
if [[ ${#MISSING_CMDS[@]} -gt 0 ]]; then
    log "Installing missing dependencies: ${MISSING_CMDS[*]}..."
    $PKG_UPDATE
    $PKG_INSTALL "${MISSING_CMDS[@]}" || error "Failed to install dependencies"
    success "Dependencies installed successfully"
fi

# Install Zsh if not present
if ! command -v zsh >/dev/null; then
    log "Installing Zsh..."
    $PKG_UPDATE
    $PKG_INSTALL "$ZSH_PACKAGE" || error "Failed to install Zsh"
    success "Zsh installed successfully"
else
    log "Zsh already installed at $(command -v zsh)"
fi

# Verify Zsh is in /etc/shells
ZSH_PATH="$(command -v zsh)"
if ! grep -qxF "$ZSH_PATH" /etc/shells; then
    log "Adding $ZSH_PATH to /etc/shells..."
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null || 
        error "Failed to add Zsh to /etc/shells"
    success "Added Zsh to /etc/shells"
fi

# Set default shell
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    log "Setting Zsh as default shell..."
    sudo chsh -s "$ZSH_PATH" "$USER" || error "Failed to set Zsh as default shell"
    success "Zsh set as default shell"
else
    log "Zsh already set as default shell"
fi

# Install Oh My Zsh
OMZ_DIR="${HOME}/.oh-my-zsh"
if [[ ! -d "$OMZ_DIR" ]]; then
    log "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || 
        error "Failed to install Oh My Zsh"
    success "Oh My Zsh installed successfully"
else
    log "Oh My Zsh already installed"
    
    # Update Oh My Zsh if already installed
    log "Updating Oh My Zsh..."
    (cd "$OMZ_DIR" && git pull -q) || warn "Failed to update Oh My Zsh"
fi

# Ensure .zshrc exists
ZSHRC="${HOME}/.zshrc"
if [[ ! -f "$ZSHRC" ]]; then
    log "Creating initial .zshrc..."
    cp "$OMZ_DIR/templates/zshrc.zsh-template" "$ZSHRC" || error "Failed to create .zshrc"
    success "Created initial .zshrc"
else
    # Backup existing .zshrc before modification
    backup_file "$ZSHRC"
fi

# Configure theme and plugins
log "Configuring theme and plugins in .zshrc..."
PLUGINS=(git zsh-autosuggestions colored-man-pages zsh-completions zsh-history-substring-search pass)
SYNTAX_HIGHLIGHTING="zsh-syntax-highlighting"

# Use sed to update theme and plugins in .zshrc
# Set the theme to fox
if grep -q "^ZSH_THEME=" "$ZSHRC"; then
    # Different sed syntax for macOS and Linux
    if [[ "$PLATFORM" == "macos" ]]; then
        sed -i '' 's/^ZSH_THEME=.*$/ZSH_THEME="fox"/' "$ZSHRC"
    else
        sed -i 's/^ZSH_THEME=.*$/ZSH_THEME="fox"/' "$ZSHRC"
    fi
    log "Set ZSH_THEME to fox"
else
    echo 'ZSH_THEME="fox"' >> "$ZSHRC"
    log "Added ZSH_THEME=fox to .zshrc"
fi

# Set the plugins
PLUGIN_STRING=$(IFS=' ' ; echo "${PLUGINS[*]} $SYNTAX_HIGHLIGHTING")
if grep -q "^plugins=(" "$ZSHRC"; then
    # Different sed syntax for macOS and Linux
    if [[ "$PLATFORM" == "macos" ]]; then
        sed -i '' -E "s/^plugins=\(.*\)$/plugins=($PLUGIN_STRING)/" "$ZSHRC"
    else
        sed -i -E "s/^plugins=\(.*\)$/plugins=($PLUGIN_STRING)/" "$ZSHRC"
    fi
else
    echo "plugins=($PLUGIN_STRING)" >> "$ZSHRC"
fi

success "Theme and plugins configured"

# Verify the fox theme exists, download if needed
THEMES_DIR="${ZSH_CUSTOM:-${OMZ_DIR}/custom}/themes"
FOX_THEME="${THEMES_DIR}/fox.zsh-theme"

if [[ ! -f "$FOX_THEME" ]]; then
    log "Fox theme not found, creating theme directory if needed..."
    mkdir -p "$THEMES_DIR"
    
    log "Downloading fox theme..."
    curl -fsSL "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/themes/fox.zsh-theme" -o "$FOX_THEME" || warn "Failed to download fox theme"
    
    if [[ -f "$FOX_THEME" ]]; then
        success "Fox theme installed successfully"
    else
        warn "Fox theme installation failed. Default theme will be used instead."
    fi
else
    log "Fox theme already installed"
fi

# Plugin installation function with improved error handling
clone_plugin() {
    local repo="$1"
    local dest="$2"
    
    if [[ ! -d "$dest" ]]; then
        log "Cloning $repo..."
        git clone --quiet --depth 1 "$repo" "$dest" || {
            warn "Error cloning $repo. Continuing with installation."
            return 1
        }
        success "Plugin installed: $(basename "$dest")"
    else
        log "Updating plugin: $(basename "$dest")"
        (cd "$dest" && git pull -q) || warn "Failed to update plugin: $(basename "$dest")"
    fi
}

# Install plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-${OMZ_DIR}/custom}"
PLUGINS_DIR="${ZSH_CUSTOM}/plugins"
mkdir -p "$PLUGINS_DIR"

declare -a PLUGIN_REPOS=(
    "zsh-completions https://github.com/zsh-users/zsh-completions"
    "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git"
    "zsh-history-substring-search https://github.com/zsh-users/zsh-history-substring-search"
)

log "Installing plugins..."
for plugin in "${PLUGIN_REPOS[@]}"; do
    name="${plugin%% *}"
    url="${plugin#* }"
    clone_plugin "$url" "${PLUGINS_DIR}/${name}"
done

# Add useful aliases to .zshrc if they don't exist
log "Adding useful aliases..."
cat << 'EOF' >> "$ZSHRC"

# Added by $SCRIPT_NAME
# Useful aliases
if ! grep -q "# Custom aliases" "$ZSHRC"; then
    cat << 'ALIASES' >> "$ZSHRC"

# Custom aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias zshreload='source ~/.zshrc'
alias zshconfig='${EDITOR:-nano} ~/.zshrc'
alias omzconfig='${EDITOR:-nano} ~/.oh-my-zsh'
ALIASES
fi
EOF

# Final setup
success "Setup complete! Starting new Zsh session..."
log "Your previous .zshrc has been backed up to ${ZSHRC}${BACKUP_SUFFIX}"
log "To apply changes without starting a new session, run: source ~/.zshrc"

# Prompt to start new shell or just source the config
read -r -p "Start new Zsh session now? [Y/n] " response
response=${response,,} # Convert to lowercase
if [[ $response =~ ^(yes|y|)$ ]]; then
    exec zsh -l
else
    log "You can start a new Zsh session manually when ready"
fi
