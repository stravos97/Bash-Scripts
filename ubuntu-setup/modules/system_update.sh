#!/bin/bash
# system_update.sh - System update and package management
# This module handles Ubuntu system updates and package management

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Function to update system packages
update_system() {
    print_section_header "Updating system packages"
    
    # Update package lists
    echo -e "${YELLOW}Updating package lists...${NC}" | tee -a "$LOG_FILE"
    apt update
    check_status "System package list updated" || return 1
    
    # Upgrade packages
    echo -e "${YELLOW}Upgrading packages...${NC}" | tee -a "$LOG_FILE"
    apt upgrade -y
    check_status "System packages upgraded" || return 1
    
    # Check if a reboot is required
    if [ -f /var/run/reboot-required ]; then
        echo -e "${YELLOW}A system reboot is required to complete the update process.${NC}" | tee -a "$LOG_FILE"
        if ask_yes_no "Would you like to reboot now?"; then
            echo -e "${GREEN}System will reboot in 10 seconds...${NC}" | tee -a "$LOG_FILE"
            sleep 10
            reboot
        else
            echo -e "${YELLOW}Please remember to reboot your system later.${NC}" | tee -a "$LOG_FILE"
        fi
    else
        echo -e "${GREEN}System is up to date. No reboot required.${NC}" | tee -a "$LOG_FILE"
    fi
    
    return 0
}

# Function to configure automatic updates
configure_automatic_updates() {
    print_section_header "Configuring Automatic Updates"
    
    # Install unattended-upgrades if not already installed
    if ! is_package_installed "unattended-upgrades"; then
        echo -e "${YELLOW}Installing unattended-upgrades package...${NC}" | tee -a "$LOG_FILE"
        apt install unattended-upgrades -y
        check_status "Unattended-upgrades package installed" || return 1
    else
        echo -e "${GREEN}Unattended-upgrades package is already installed.${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Install update-notifier-common if not already installed (needed for reboot detection)
    if ! is_package_installed "update-notifier-common"; then
        echo -e "${YELLOW}Installing update-notifier-common package...${NC}" | tee -a "$LOG_FILE"
        apt install update-notifier-common -y
        check_status "Update-notifier-common package installed" || return 1
    fi
    
    # Configure unattended-upgrades
    echo -e "${YELLOW}Configuring unattended-upgrades...${NC}" | tee -a "$LOG_FILE"
    
    # Backup original configuration files if they exist
    if [ -f "/etc/apt/apt.conf.d/50unattended-upgrades" ]; then
        backup_file "/etc/apt/apt.conf.d/50unattended-upgrades"
    fi
    
    if [ -f "/etc/apt/apt.conf.d/20auto-upgrades" ]; then
        backup_file "/etc/apt/apt.conf.d/20auto-upgrades"
    fi
    
    # Create 20auto-upgrades configuration file
    cat > "/etc/apt/apt.conf.d/20auto-upgrades" << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    check_status "Created auto-upgrades configuration" || return 1
    
    # Configuration options
    local auto_reboot
    local auto_reboot_time
    local email_notification
    local email_address
    
    # Ask about automatic reboots
    if ask_yes_no "Do you want to enable automatic reboots after updates?"; then
        auto_reboot="true"
        
        echo -n "Enter preferred reboot time (24h format, e.g., 02:00): "
        read -r auto_reboot_time
        
        # Default to 02:00 if invalid format
        if [[ ! "$auto_reboot_time" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
            echo -e "${YELLOW}Invalid time format. Using default (02:00).${NC}" | tee -a "$LOG_FILE"
            auto_reboot_time="02:00"
        fi
    else
        auto_reboot="false"
        auto_reboot_time="02:00"
    fi
    
    # Ask about email notifications
    if ask_yes_no "Do you want to receive email notifications for updates?"; then
        email_notification="true"
        
        echo -n "Enter email address for notifications: "
        read -r email_address
        
        # Basic email validation
        if [[ ! "$email_address" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo -e "${YELLOW}Invalid email format. Email notifications will be disabled.${NC}" | tee -a "$LOG_FILE"
            email_notification="false"
        fi
        
        # Install mailutils if email notifications are enabled
        if [ "$email_notification" = "true" ]; then
            echo -e "${YELLOW}Installing mailutils for email notifications...${NC}" | tee -a "$LOG_FILE"
            apt install mailutils -y
            check_status "Mailutils installed" || echo -e "${YELLOW}Failed to install mailutils. Email notifications may not work.${NC}" | tee -a "$LOG_FILE"
        fi
    else
        email_notification="false"
        email_address=""
    fi
    
    # Create 50unattended-upgrades configuration file
    cat > "/etc/apt/apt.conf.d/50unattended-upgrades" << EOF
// Unattended-Upgrade::Origins-Pattern controls which packages are upgraded
Unattended-Upgrade::Origins-Pattern {
    "origin=Ubuntu,archive=focal-security";
    "origin=Ubuntu,archive=focal-updates";
};

// List of packages to not update
Unattended-Upgrade::Package-Blacklist {
//    "vim";
//    "libc6";
//    "libc6-dev";
//    "libc6-i686";
};

// Automatic reboot configuration
Unattended-Upgrade::Automatic-Reboot "$auto_reboot";
Unattended-Upgrade::Automatic-Reboot-Time "$auto_reboot_time";

// Email notifications
Unattended-Upgrade::Mail "$email_address";
Unattended-Upgrade::MailOnlyOnError "$email_notification";

// Remove unused dependencies
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Remove unused kernel packages
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Allow package downgrade if needed
Unattended-Upgrade::Allow-downgrade "false";

// Split the upgrade into smallest possible chunks
Unattended-Upgrade::MinimalSteps "true";
EOF
    check_status "Created unattended-upgrades configuration" || return 1
    
    # Enable and start the unattended-upgrades service
    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades
    check_status "Unattended-upgrades service enabled and restarted" || return 1
    
    echo -e "${GREEN}Automatic updates configured successfully.${NC}" | tee -a "$LOG_FILE"
    if [ "$auto_reboot" = "true" ]; then
        echo -e "System will automatically reboot at ${YELLOW}$auto_reboot_time${NC} when necessary." | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}Automatic reboots are disabled. You'll need to manually reboot when prompted.${NC}" | tee -a "$LOG_FILE"
    fi
    
    if [ "$email_notification" = "true" ]; then
        echo -e "Email notifications will be sent to ${YELLOW}$email_address${NC}" | tee -a "$LOG_FILE"
    fi
    
    return 0
}

# Function to install common utilities
install_common_utilities() {
    print_section_header "Installing Common Utilities"
    
    # Define array of common utilities
    local utilities=(
        "htop"          # Interactive process viewer
        "tmux"          # Terminal multiplexer
        "net-tools"     # Network utilities
        "dnsutils"      # DNS utilities
        "curl"          # Command line tool for transferring data
        "wget"          # Internet file retriever
        "vim"           # Text editor
        "git"           # Version control
        "unzip"         # Extraction utility
        "zip"           # Compression utility
        "tree"          # Directory listing
        "ncdu"          # Disk usage analyzer
        "iotop"         # I/O monitoring
        "rsync"         # Fast file copying tool
    )
    
    echo -e "${YELLOW}The following utilities will be installed:${NC}" | tee -a "$LOG_FILE"
    for util in "${utilities[@]}"; do
        echo "  - $util" | tee -a "$LOG_FILE"
    done
    
    if ask_yes_no "Do you want to proceed with installation?"; then
        # Update package list
        apt update
        
        # Install each utility
        for util in "${utilities[@]}"; do
            if ! is_package_installed "$util"; then
                echo -e "${YELLOW}Installing $util...${NC}" | tee -a "$LOG_FILE"
                apt install "$util" -y
                check_status "Installed $util" || echo -e "${RED}Failed to install $util.${NC}" | tee -a "$LOG_FILE"
            else
                echo -e "${GREEN}$util is already installed.${NC}" | tee -a "$LOG_FILE"
            fi
        done
        
        echo -e "${GREEN}Common utilities installation complete.${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}Skipping installation of common utilities.${NC}" | tee -a "$LOG_FILE"
    fi
    
    return 0
}

# Function to clean up unnecessary packages and files
clean_system() {
    print_section_header "Cleaning System"
    
    # Remove orphaned packages
    echo -e "${YELLOW}Removing orphaned packages...${NC}" | tee -a "$LOG_FILE"
    apt autoremove -y
    check_status "Orphaned packages removed" || echo -e "${RED}Failed to remove orphaned packages.${NC}" | tee -a "$LOG_FILE"
    
    # Clean package cache
    echo -e "${YELLOW}Cleaning package cache...${NC}" | tee -a "$LOG_FILE"
    apt clean
    check_status "Package cache cleaned" || echo -e "${RED}Failed to clean package cache.${NC}" | tee -a "$LOG_FILE"
    
    # Clean tmp directory
    echo -e "${YELLOW}Cleaning temporary files...${NC}" | tee -a "$LOG_FILE"
    rm -rf /tmp/*
    check_status "Temporary files cleaned" || echo -e "${RED}Failed to clean temporary files.${NC}" | tee -a "$LOG_FILE"
    
    # Clean journalctl logs
    echo -e "${YELLOW}Cleaning system logs...${NC}" | tee -a "$LOG_FILE"
    journalctl --vacuum-time=7d
    check_status "System logs cleaned" || echo -e "${RED}Failed to clean system logs.${NC}" | tee -a "$LOG_FILE"
    
    echo -e "${GREEN}System cleaning complete.${NC}" | tee -a "$LOG_FILE"
    
    return 0
}