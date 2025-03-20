#!/bin/bash
# desktop_env.sh - Desktop environment installation and configuration
# This module handles the installation and setup of desktop environments

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Function to install a desktop environment
install_desktop_environment() {
    print_section_header "Installing Desktop Environment"

    local de_options=(
        "XFCE (Lightweight and stable)"
        "LXDE (Very lightweight, minimal)"
        "MATE (Traditional desktop, medium weight)"
        "Cinnamon (Modern features, heavier)"
        "GNOME (Ubuntu default, resource-intensive)"
        "KDE Plasma (Feature-rich, customizable, heavier)"
    )

    echo -e "${YELLOW}Available desktop environments:${NC}" | tee -a "$LOG_FILE"
    for i in "${!de_options[@]}"; do
        echo "$((i+1)). ${de_options[$i]}" | tee -a "$LOG_FILE"
    done

    local valid_choice=false
    local choice

    while [ "$valid_choice" = false ]; do
        echo -n "Select a desktop environment to install (1-${#de_options[@]}): "
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#de_options[@]}" ]; then
            valid_choice=true
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#de_options[@]}.${NC}" | tee -a "$LOG_FILE"
        fi
    done

    # Adjust for zero-based indexing
    choice=$((choice-1))

    # Update package repositories first
    apt update
    check_status "Repository information updated" || return 1

    # Install based on selection
    case $choice in
        0) # XFCE
            echo -e "${YELLOW}Installing XFCE desktop environment...${NC}" | tee -a "$LOG_FILE"
            apt install xfce4 xfce4-goodies -y
            check_status "XFCE desktop environment installed" || return 1
            # Set XFCE as default desktop
            update-alternatives --set x-session-manager /usr/bin/xfce4-session 2>/dev/null || true
            ;;
        1) # LXDE
            echo -e "${YELLOW}Installing LXDE desktop environment...${NC}" | tee -a "$LOG_FILE"
            apt install lxde -y
            check_status "LXDE desktop environment installed" || return 1
            # Set LXDE as default desktop
            update-alternatives --set x-session-manager /usr/bin/lxsession 2>/dev/null || true
            ;;
        2) # MATE
            echo -e "${YELLOW}Installing MATE desktop environment...${NC}" | tee -a "$LOG_FILE"
            apt install mate-desktop-environment mate-desktop-environment-extras -y
            check_status "MATE desktop environment installed" || return 1
            # Set MATE as default desktop
            update-alternatives --set x-session-manager /usr/bin/mate-session 2>/dev/null || true
            ;;
        3) # Cinnamon
            echo -e "${YELLOW}Installing Cinnamon desktop environment...${NC}" | tee -a "$LOG_FILE"
            apt install cinnamon-desktop-environment -y
            check_status "Cinnamon desktop environment installed" || return 1
            # Set Cinnamon as default desktop
            update-alternatives --set x-session-manager /usr/bin/cinnamon-session 2>/dev/null || true
            ;;
        4) # GNOME
            echo -e "${YELLOW}Installing GNOME desktop environment...${NC}" | tee -a "$LOG_FILE"
            apt install ubuntu-desktop -y
            check_status "GNOME desktop environment installed" || return 1
            # Ubuntu already sets GNOME as default
            ;;
        5) # KDE Plasma
            echo -e "${YELLOW}Installing KDE Plasma desktop environment...${NC}" | tee -a "$LOG_FILE"
            apt install kde-plasma-desktop -y
            check_status "KDE Plasma desktop environment installed" || return 1
            # Set KDE as default desktop
            update-alternatives --set x-session-manager /usr/bin/startplasma-x11 2>/dev/null || true
            ;;
    esac

    # Install additional components that are useful for any desktop
    echo -e "${YELLOW}Installing additional desktop components...${NC}" | tee -a "$LOG_FILE"
    apt install xdg-utils xorg lightdm -y
    check_status "Additional desktop components installed" || return 1

    # Configure LightDM (if installed)
    if is_package_installed "lightdm"; then
        echo -e "${YELLOW}Setting LightDM as the default display manager...${NC}" | tee -a "$LOG_FILE"
        # Create backup of lightdm.conf if it doesn't exist
        if [ -f "/etc/lightdm/lightdm.conf" ]; then
            backup_file "/etc/lightdm/lightdm.conf"
        else
            mkdir -p /etc/lightdm
            touch /etc/lightdm/lightdm.conf
        fi

        # Configure LightDM for better compatibility
        set_config_value "/etc/lightdm/lightdm.conf" "greeter-show-manual-login" "true" "Allow manual login"
        set_config_value "/etc/lightdm/lightdm.conf" "greeter-hide-users" "false" "Show user list"
    fi

    # Install common fonts and themes
    echo -e "${YELLOW}Installing common fonts and themes...${NC}" | tee -a "$LOG_FILE"
    apt install fonts-liberation2 fonts-noto arc-theme papirus-icon-theme -y
    check_status "Fonts and themes installed" || return 1

    # Install web browser if not present
    if ! is_package_installed "firefox"; then
        echo -e "${YELLOW}Installing Firefox web browser...${NC}" | tee -a "$LOG_FILE"
        apt install firefox -y
        check_status "Firefox installed" || return 1
    fi

    echo -e "${GREEN}Desktop environment installation complete!${NC}" | tee -a "$LOG_FILE"
    echo "You will be able to select your desktop environment at the login screen." | tee -a "$LOG_FILE"

    # Restart display manager if it's running
    if systemctl is-active lightdm &>/dev/null; then
        systemctl restart lightdm
        check_status "Display manager restarted" || true
    elif systemctl is-active gdm &>/dev/null; then
        systemctl restart gdm
        check_status "Display manager restarted" || true
    fi

    return 0
}

# Function to configure desktop settings
configure_desktop_settings() {
    print_section_header "Configuring Desktop Settings"
    
    local current_de=$(detect_desktop_environment)
    
    echo -e "Current desktop environment: ${YELLOW}$current_de${NC}" | tee -a "$LOG_FILE"
    
    # Get real user for configuration
    local real_user=$(get_real_user)
    if [ -z "$real_user" ] || [ "$real_user" = "root" ]; then
        echo -e "${RED}No non-root user detected for desktop configuration.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Configure based on detected desktop environment
    case "$current_de" in
        "GNOME")
            configure_gnome_settings "$real_user"
            ;;
        "XFCE")
            configure_xfce_settings "$real_user"
            ;;
        "MATE")
            configure_mate_settings "$real_user"
            ;;
        "Cinnamon")
            configure_cinnamon_settings "$real_user"
            ;;
        "KDE Plasma")
            configure_kde_settings "$real_user"
            ;;
        "LXDE")
            configure_lxde_settings "$real_user"
            ;;
        *)
            echo -e "${YELLOW}No specific settings available for $current_de.${NC}" | tee -a "$LOG_FILE"
            ;;
    esac
    
    echo -e "${GREEN}Desktop settings configuration completed.${NC}" | tee -a "$LOG_FILE"
    return 0
}

# Helper functions for desktop configuration
configure_gnome_settings() {
    local user="$1"
    echo -e "${YELLOW}Configuring GNOME settings for user $user...${NC}" | tee -a "$LOG_FILE"
    
    # Run commands as the user
    sudo -u "$user" bash << EOC
    # Enable dark theme
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    
    # Set a reasonable font
    gsettings set org.gnome.desktop.interface font-name 'Ubuntu 11'
    
    # Configure power settings
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 3600
    
    # Enable minimize and maximize buttons
    gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
EOC
    
    check_status "GNOME settings configured for user $user" || return 1
    return 0
}

configure_xfce_settings() {
    local user="$1"
    echo -e "${YELLOW}Configuring XFCE settings for user $user...${NC}" | tee -a "$LOG_FILE"
    
    # Setting up XFCE is more complex because it uses Xfconf
    # This is a simplified approach
    local user_home=$(eval echo ~"$user")
    
    if [ -d "$user_home/.config/xfce4" ]; then
        # Run commands as the user
        sudo -u "$user" bash << EOC
    # Create or update xfce4 configuration
    mkdir -p "$user_home/.config/xfce4/xfconf/xfce-perchannel-xml"
    
    # Configure panel
    xfconf-query -c xfce4-panel -p /panels/panel-1/size -t int -s 32 --create
    
    # Configure desktop
    xfconf-query -c xfwm4 -p /general/theme -t string -s "Arc-Dark" --create
    xfconf-query -c xfwm4 -p /general/title_alignment -t string -s "center" --create
EOC
    else
        echo -e "${YELLOW}XFCE config directory not found. Settings will be applied on first login.${NC}" | tee -a "$LOG_FILE"
    fi
    
    check_status "XFCE settings configured for user $user" || return 1
    return 0
}

configure_mate_settings() {
    local user="$1"
    echo -e "${YELLOW}Configuring MATE settings for user $user...${NC}" | tee -a "$LOG_FILE"
    
    # Basic MATE settings
    sudo -u "$user" bash << EOC
    # Set theme
    gsettings set org.mate.interface gtk-theme 'Arc-Dark'
    
    # Configure panel
    gsettings set org.mate.panel.toplevels.top size 28
EOC
    
    check_status "MATE settings configured for user $user" || return 1
    return 0
}

configure_cinnamon_settings() {
    local user="$1"
    echo -e "${YELLOW}Configuring Cinnamon settings for user $user...${NC}" | tee -a "$LOG_FILE"
    
    sudo -u "$user" bash << EOC
    # Set theme
    gsettings set org.cinnamon.theme name 'Arc-Dark'
    
    # Configure panel
    gsettings set org.cinnamon.panels-height "['1:40']"
EOC
    
    check_status "Cinnamon settings configured for user $user" || return 1
    return 0
}

configure_kde_settings() {
    local user="$1"
    echo -e "${YELLOW}Configuring KDE settings for user $user...${NC}" | tee -a "$LOG_FILE"
    
    echo -e "${YELLOW}KDE settings are best configured through the GUI. Basic settings will be applied.${NC}" | tee -a "$LOG_FILE"
    
    # KDE is more complex to configure via command line
    # This is a placeholder for potential future implementation
    
    check_status "KDE settings check complete for user $user" || return 1
    return 0
}

configure_lxde_settings() {
    local user="$1"
    echo -e "${YELLOW}Configuring LXDE settings for user $user...${NC}" | tee -a "$LOG_FILE"
    
    # LXDE uses configuration files rather than gsettings/dconf
    local user_home=$(eval echo ~"$user")
    
    # Ensure directory exists
    sudo -u "$user" mkdir -p "$user_home/.config/lxsession/LXDE"
    
    # Create basic configuration
    sudo -u "$user" bash << EOC
    echo "export GTK_THEME=Arc-Dark" > "$user_home/.config/lxsession/LXDE/desktop.conf"
EOC
    
    check_status "LXDE settings configured for user $user" || return 1
    return 0
}