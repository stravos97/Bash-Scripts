#!/bin/bash
# zsh_setup.sh - ZSH shell installation and configuration
# This module handles the installation of ZSH, Oh My Zsh, and plugins

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Main function for ZSH setup
zsh_setup() {
    print_section_header "Setting up ZSH Shell"
    
    # Install ZSH if not already installed
    if ! is_package_installed "zsh"; then
        echo -e "${YELLOW}Installing ZSH...${NC}" | tee -a "$LOG_FILE"
        apt install zsh -y
        check_status "ZSH installed" || return 1
    else
        echo -e "${GREEN}ZSH is already installed.${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Verify ZSH is in /etc/shells
    ZSH_PATH="$(command -v zsh)"
    if ! grep -qxF "$ZSH_PATH" /etc/shells; then
        echo -e "${YELLOW}Adding $ZSH_PATH to /etc/shells...${NC}" | tee -a "$LOG_FILE"
        echo "$ZSH_PATH" | tee -a /etc/shells >/dev/null
        check_status "Added ZSH to /etc/shells" || return 1
    else
        echo -e "${GREEN}ZSH is already in /etc/shells.${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Get the username for configuration
    local user
    if [ "$(id -u)" -eq 0 ]; then
        user=$(get_real_user)
        if [ -z "$user" ] || [ "$user" = "root" ]; then
            echo -n "Enter the username for ZSH configuration: "
            read -r user
            if ! id "$user" >/dev/null 2>&1; then
                echo -e "${RED}User '$user' does not exist.${NC}" | tee -a "$LOG_FILE"
                return 1
            fi
        fi
    else
        user=$(whoami)
    fi
    
    local user_home
    user_home=$(eval echo ~"$user")
    
    # Install Oh My ZSH if not already installed
    local OMZ_DIR="${user_home}/.oh-my-zsh"
    if [ ! -d "$OMZ_DIR" ]; then
        echo -e "${YELLOW}Installing Oh My ZSH for user $user...${NC}" | tee -a "$LOG_FILE"
        # We need to install Oh My ZSH as the user, not as root
        sudo -u "$user" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        check_status "Oh My ZSH installed" || return 1
    else
        echo -e "${GREEN}Oh My ZSH is already installed for user $user.${NC}" | tee -a "$LOG_FILE"
        # Update Oh My ZSH if already installed
        echo -e "${YELLOW}Updating Oh My ZSH...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" bash -c "cd '$OMZ_DIR' && git pull -q"
        check_status "Oh My ZSH updated" || echo -e "${YELLOW}Failed to update Oh My ZSH.${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Configure ZSH theme and plugins
    local ZSHRC="${user_home}/.zshrc"
    if [ ! -f "$ZSHRC" ]; then
        echo -e "${YELLOW}Creating initial .zshrc...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" cp "$OMZ_DIR/templates/zshrc.zsh-template" "$ZSHRC"
        check_status "Created initial .zshrc" || return 1
    else
        # Backup existing .zshrc before modification
        backup_file "$ZSHRC"
        check_status "Backed up existing .zshrc" || echo -e "${YELLOW}Failed to backup existing .zshrc. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Set theme
    local ZSH_THEME="fox"
    echo -e "${YELLOW}Setting ZSH theme to $ZSH_THEME...${NC}" | tee -a "$LOG_FILE"
    if grep -q "^ZSH_THEME=" "$ZSHRC"; then
        sed -i "s/^ZSH_THEME=.*$/ZSH_THEME=\"$ZSH_THEME\"/" "$ZSHRC"
    else
        echo "ZSH_THEME=\"$ZSH_THEME\"" >> "$ZSHRC"
    fi
    check_status "Set ZSH theme to $ZSH_THEME" || echo -e "${YELLOW}Failed to set theme. Continuing...${NC}" | tee -a "$LOG_FILE"
    
    # Install plugins
    local ZSH_CUSTOM="${OMZ_DIR}/custom"
    local PLUGINS_DIR="${ZSH_CUSTOM}/plugins"
    sudo -u "$user" mkdir -p "$PLUGINS_DIR"
    
    # Define plugins to install
    local PLUGINS=(
        "git" 
        "zsh-autosuggestions" 
        "colored-man-pages" 
        "zsh-completions" 
        "zsh-history-substring-search"
        "zsh-syntax-highlighting"
    )
    
    # Clone plugin repositories
    echo -e "${YELLOW}Installing ZSH plugins...${NC}" | tee -a "$LOG_FILE"
    
    # Install zsh-completions plugin
    if [ ! -d "${PLUGINS_DIR}/zsh-completions" ]; then
        echo -e "${YELLOW}Installing zsh-completions plugin...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" git clone --quiet --depth 1 https://github.com/zsh-users/zsh-completions "${PLUGINS_DIR}/zsh-completions"
        check_status "Installed zsh-completions plugin" || echo -e "${YELLOW}Failed to install zsh-completions plugin. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Install zsh-autosuggestions plugin
    if [ ! -d "${PLUGINS_DIR}/zsh-autosuggestions" ]; then
        echo -e "${YELLOW}Installing zsh-autosuggestions plugin...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" git clone --quiet --depth 1 https://github.com/zsh-users/zsh-autosuggestions "${PLUGINS_DIR}/zsh-autosuggestions"
        check_status "Installed zsh-autosuggestions plugin" || echo -e "${YELLOW}Failed to install zsh-autosuggestions plugin. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Install zsh-syntax-highlighting plugin
    if [ ! -d "${PLUGINS_DIR}/zsh-syntax-highlighting" ]; then
        echo -e "${YELLOW}Installing zsh-syntax-highlighting plugin...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" git clone --quiet --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "${PLUGINS_DIR}/zsh-syntax-highlighting"
        check_status "Installed zsh-syntax-highlighting plugin" || echo -e "${YELLOW}Failed to install zsh-syntax-highlighting plugin. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Install zsh-history-substring-search plugin
    if [ ! -d "${PLUGINS_DIR}/zsh-history-substring-search" ]; then
        echo -e "${YELLOW}Installing zsh-history-substring-search plugin...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" git clone --quiet --depth 1 https://github.com/zsh-users/zsh-history-substring-search "${PLUGINS_DIR}/zsh-history-substring-search"
        check_status "Installed zsh-history-substring-search plugin" || echo -e "${YELLOW}Failed to install zsh-history-substring-search plugin. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Install fox theme if it doesn't exist
    local THEMES_DIR="${ZSH_CUSTOM}/themes"
    local FOX_THEME="${THEMES_DIR}/fox.zsh-theme"
    if [ ! -f "$FOX_THEME" ]; then
        echo -e "${YELLOW}Installing fox theme...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" mkdir -p "$THEMES_DIR"
        sudo -u "$user" curl -fsSL "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/themes/fox.zsh-theme" -o "$FOX_THEME"
        check_status "Installed fox theme" || echo -e "${YELLOW}Failed to install fox theme. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Update plugins in .zshrc
    local PLUGIN_STRING=$(IFS=' ' ; echo "${PLUGINS[*]}")
    if grep -q "^plugins=(" "$ZSHRC"; then
        sed -i -E "s/^plugins=\(.*\)$/plugins=($PLUGIN_STRING)/" "$ZSHRC"
    else
        echo "plugins=($PLUGIN_STRING)" >> "$ZSHRC"
    fi
    check_status "Updated plugins in .zshrc" || echo -e "${YELLOW}Failed to update plugins in .zshrc. Continuing...${NC}" | tee -a "$LOG_FILE"
    
    # Add useful aliases if they don't exist
    if ! grep -q "# Custom aliases" "$ZSHRC"; then
        echo -e "${YELLOW}Adding useful aliases to .zshrc...${NC}" | tee -a "$LOG_FILE"
        cat << 'EOF' >> "$ZSHRC"

# Custom aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias zshreload='source ~/.zshrc'
alias zshconfig='${EDITOR:-nano} ~/.zshrc'
alias omzconfig='${EDITOR:-nano} ~/.oh-my-zsh'
EOF
        check_status "Added useful aliases" || echo -e "${YELLOW}Failed to add aliases. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Ask if user wants to set ZSH as default shell
    if ask_yes_no "Would you like to set ZSH as the default shell for user $user?"; then
        echo -e "${YELLOW}Setting ZSH as default shell for user $user...${NC}" | tee -a "$LOG_FILE"
        chsh -s "$ZSH_PATH" "$user"
        check_status "Set ZSH as default shell for user $user" || return 1
    fi
    
    echo -e "${GREEN}ZSH setup completed successfully!${NC}" | tee -a "$LOG_FILE"
    echo -e "To use ZSH, either log out and log back in, or run: ${YELLOW}zsh${NC}" | tee -a "$LOG_FILE"
    
    return 0
}#!/bin/bash
# zsh_setup.sh - ZSH shell installation and configuration
# This module handles the installation of ZSH, Oh My Zsh, and plugins

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Main function for ZSH setup
zsh_setup() {
    print_section_header "Setting up ZSH Shell"
    
    # Install ZSH if not already installed
    if ! is_package_installed "zsh"; then
        echo -e "${YELLOW}Installing ZSH...${NC}" | tee -a "$LOG_FILE"
        apt install zsh -y
        check_status "ZSH installed" || return 1
    else
        echo -e "${GREEN}ZSH is already installed.${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Verify ZSH is in /etc/shells
    ZSH_PATH="$(command -v zsh)"
    if ! grep -qxF "$ZSH_PATH" /etc/shells; then
        echo -e "${YELLOW}Adding $ZSH_PATH to /etc/shells...${NC}" | tee -a "$LOG_FILE"
        echo "$ZSH_PATH" | tee -a /etc/shells >/dev/null
        check_status "Added ZSH to /etc/shells" || return 1
    else
        echo -e "${GREEN}ZSH is already in /etc/shells.${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Get the username for configuration
    local user
    if [ "$(id -u)" -eq 0 ]; then
        user=$(get_real_user)
        if [ -z "$user" ] || [ "$user" = "root" ]; then
            echo -n "Enter the username for ZSH configuration: "
            read -r user
            if ! id "$user" >/dev/null 2>&1; then
                echo -e "${RED}User '$user' does not exist.${NC}" | tee -a "$LOG_FILE"
                return 1
            fi
        fi
    else
        user=$(whoami)
    fi
    
    local user_home
    user_home=$(eval echo ~"$user")
    
    # Install Oh My ZSH if not already installed
    local OMZ_DIR="${user_home}/.oh-my-zsh"
    if [ ! -d "$OMZ_DIR" ]; then
        echo -e "${YELLOW}Installing Oh My ZSH for user $user...${NC}" | tee -a "$LOG_FILE"
        # We need to install Oh My ZSH as the user, not as root
        sudo -u "$user" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        check_status "Oh My ZSH installed" || return 1
    else
        echo -e "${GREEN}Oh My ZSH is already installed for user $user.${NC}" | tee -a "$LOG_FILE"
        # Update Oh My ZSH if already installed
        echo -e "${YELLOW}Updating Oh My ZSH...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" bash -c "cd '$OMZ_DIR' && git pull -q"
        check_status "Oh My ZSH updated" || echo -e "${YELLOW}Failed to update Oh My ZSH.${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Configure ZSH theme and plugins
    local ZSHRC="${user_home}/.zshrc"
    if [ ! -f "$ZSHRC" ]; then
        echo -e "${YELLOW}Creating initial .zshrc...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" cp "$OMZ_DIR/templates/zshrc.zsh-template" "$ZSHRC"
        check_status "Created initial .zshrc" || return 1
    else
        # Backup existing .zshrc before modification
        backup_file "$ZSHRC"
        check_status "Backed up existing .zshrc" || echo -e "${YELLOW}Failed to backup existing .zshrc. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Set theme
    local ZSH_THEME="fox"
    echo -e "${YELLOW}Setting ZSH theme to $ZSH_THEME...${NC}" | tee -a "$LOG_FILE"
    if grep -q "^ZSH_THEME=" "$ZSHRC"; then
        sed -i "s/^ZSH_THEME=.*$/ZSH_THEME=\"$ZSH_THEME\"/" "$ZSHRC"
    else
        echo "ZSH_THEME=\"$ZSH_THEME\"" >> "$ZSHRC"
    fi
    check_status "Set ZSH theme to $ZSH_THEME" || echo -e "${YELLOW}Failed to set theme. Continuing...${NC}" | tee -a "$LOG_FILE"
    
    # Install plugins
    local ZSH_CUSTOM="${OMZ_DIR}/custom"
    local PLUGINS_DIR="${ZSH_CUSTOM}/plugins"
    sudo -u "$user" mkdir -p "$PLUGINS_DIR"
    
    # Define plugins to install
    local PLUGINS=(
        "git" 
        "zsh-autosuggestions" 
        "colored-man-pages" 
        "zsh-completions" 
        "zsh-history-substring-search"
        "zsh-syntax-highlighting"
    )
    
    # Clone plugin repositories
    echo -e "${YELLOW}Installing ZSH plugins...${NC}" | tee -a "$LOG_FILE"
    
    # Install zsh-completions plugin
    if [ ! -d "${PLUGINS_DIR}/zsh-completions" ]; then
        echo -e "${YELLOW}Installing zsh-completions plugin...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" git clone --quiet --depth 1 https://github.com/zsh-users/zsh-completions "${PLUGINS_DIR}/zsh-completions"
        check_status "Installed zsh-completions plugin" || echo -e "${YELLOW}Failed to install zsh-completions plugin. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Install zsh-autosuggestions plugin
    if [ ! -d "${PLUGINS_DIR}/zsh-autosuggestions" ]; then
        echo -e "${YELLOW}Installing zsh-autosuggestions plugin...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" git clone --quiet --depth 1 https://github.com/zsh-users/zsh-autosuggestions "${PLUGINS_DIR}/zsh-autosuggestions"
        check_status "Installed zsh-autosuggestions plugin" || echo -e "${YELLOW}Failed to install zsh-autosuggestions plugin. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Install zsh-syntax-highlighting plugin
    if [ ! -d "${PLUGINS_DIR}/zsh-syntax-highlighting" ]; then
        echo -e "${YELLOW}Installing zsh-syntax-highlighting plugin...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" git clone --quiet --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "${PLUGINS_DIR}/zsh-syntax-highlighting"
        check_status "Installed zsh-syntax-highlighting plugin" || echo -e "${YELLOW}Failed to install zsh-syntax-highlighting plugin. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Install zsh-history-substring-search plugin
    if [ ! -d "${PLUGINS_DIR}/zsh-history-substring-search" ]; then
        echo -e "${YELLOW}Installing zsh-history-substring-search plugin...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" git clone --quiet --depth 1 https://github.com/zsh-users/zsh-history-substring-search "${PLUGINS_DIR}/zsh-history-substring-search"
        check_status "Installed zsh-history-substring-search plugin" || echo -e "${YELLOW}Failed to install zsh-history-substring-search plugin. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Install fox theme if it doesn't exist
    local THEMES_DIR="${ZSH_CUSTOM}/themes"
    local FOX_THEME="${THEMES_DIR}/fox.zsh-theme"
    if [ ! -f "$FOX_THEME" ]; then
        echo -e "${YELLOW}Installing fox theme...${NC}" | tee -a "$LOG_FILE"
        sudo -u "$user" mkdir -p "$THEMES_DIR"
        sudo -u "$user" curl -fsSL "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/themes/fox.zsh-theme" -o "$FOX_THEME"
        check_status "Installed fox theme" || echo -e "${YELLOW}Failed to install fox theme. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Update plugins in .zshrc
    local PLUGIN_STRING=$(IFS=' ' ; echo "${PLUGINS[*]}")
    if grep -q "^plugins=(" "$ZSHRC"; then
        sed -i -E "s/^plugins=\(.*\)$/plugins=($PLUGIN_STRING)/" "$ZSHRC"
    else
        echo "plugins=($PLUGIN_STRING)" >> "$ZSHRC"
    fi
    check_status "Updated plugins in .zshrc" || echo -e "${YELLOW}Failed to update plugins in .zshrc. Continuing...${NC}" | tee -a "$LOG_FILE"
    
    # Add useful aliases if they don't exist
    if ! grep -q "# Custom aliases" "$ZSHRC"; then
        echo -e "${YELLOW}Adding useful aliases to .zshrc...${NC}" | tee -a "$LOG_FILE"
        cat << 'EOF' >> "$ZSHRC"

# Custom aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias zshreload='source ~/.zshrc'
alias zshconfig='${EDITOR:-nano} ~/.zshrc'
alias omzconfig='${EDITOR:-nano} ~/.oh-my-zsh'
EOF
        check_status "Added useful aliases" || echo -e "${YELLOW}Failed to add aliases. Continuing...${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Ask if user wants to set ZSH as default shell
    if ask_yes_no "Would you like to set ZSH as the default shell for user $user?"; then
        echo -e "${YELLOW}Setting ZSH as default shell for user $user...${NC}" | tee -a "$LOG_FILE"
        chsh -s "$ZSH_PATH" "$user"
        check_status "Set ZSH as default shell for user $user" || return 1
    fi
    
    echo -e "${GREEN}ZSH setup completed successfully!${NC}" | tee -a "$LOG_FILE"
    echo -e "To use ZSH, either log out and log back in, or run: ${YELLOW}zsh${NC}" | tee -a "$LOG_FILE"
    
    return 0
}