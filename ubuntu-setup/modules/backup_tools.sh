#!/bin/bash
# backup_tools.sh - Installation and configuration of backup tools
# This module handles the installation of BorgBackup and Vorta

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Function to install BorgBackup from source
install_borg_backup() {
    print_section_header "Installing BorgBackup"

    # Check if Borg is already installed
    if command_exists borg; then
        echo -e "${GREEN}BorgBackup is already installed.${NC}" | tee -a "$LOG_FILE"
        return 0
    fi

    # Install build dependencies
    echo -e "${YELLOW}Installing build dependencies...${NC}" | tee -a "$LOG_FILE"
    apt install -y python3-dev python3-pip pkg-config libacl1-dev libssl-dev \
                   liblz4-dev libzstd-dev libxxhash-dev
    check_status "Installed build dependencies" || return 1

    # Install Borg using pip
    echo -e "${YELLOW}Installing BorgBackup...${NC}" | tee -a "$LOG_FILE"
    pip3 install --upgrade borgbackup
    check_status "Installed BorgBackup" || return 1

    # Verify installation
    if command_exists borg; then
        echo -e "${GREEN}BorgBackup has been installed successfully.${NC}" | tee -a "$LOG_FILE"
        echo -e "Version: $(borg --version)" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}Failed to verify BorgBackup installation. Check PATH or try reinstalling.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    return 0
}

# Function to install Vorta from source
install_vorta_from_source() {
    print_section_header "Installing Vorta from source"

    # Check if Vorta is already installed
    if source_installed "vorta"; then
        echo -e "${GREEN}Vorta is already installed. Skipping installation.${NC}" | tee -a "$LOG_FILE"
        return 0
    fi

    # Install build dependencies
    echo -e "${YELLOW}Installing build dependencies...${NC}" | tee -a "$LOG_FILE"
    apt install -y git python3-pip python3-dev python3-setuptools python3-wheel python3-all \
                   python3-pyqt5 python3-pyqt5.qtsvg libfuse-dev pkg-config
    check_status "Installed build dependencies" || return 1

    # Create build directory if it doesn't exist
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR" || { echo -e "${RED}Failed to change to build directory.${NC}" | tee -a "$LOG_FILE"; return 1; }

    # Clone Vorta repository if it doesn't exist
    if [ ! -d "$BUILD_DIR/vorta" ]; then
        echo -e "${YELLOW}Cloning Vorta repository...${NC}" | tee -a "$LOG_FILE"
        git clone https://github.com/borgbase/vorta.git
        check_status "Cloned Vorta repository" || return 1
    else
        echo -e "${GREEN}Vorta repository already exists. Updating...${NC}" | tee -a "$LOG_FILE"
        cd "$BUILD_DIR/vorta" || { echo -e "${RED}Failed to change to Vorta directory.${NC}" | tee -a "$LOG_FILE"; return 1; }
        git pull
        check_status "Updated Vorta repository" || return 1
    fi

    cd "$BUILD_DIR/vorta" || { echo -e "${RED}Failed to change to Vorta directory.${NC}" | tee -a "$LOG_FILE"; return 1; }

    # Install Vorta
    echo -e "${YELLOW}Installing Vorta...${NC}" | tee -a "$LOG_FILE"
    pip3 install --upgrade .
    check_status "Installed Vorta" || return 1

    # Create desktop shortcut
    if [ ! -f "/usr/share/applications/vorta.desktop" ]; then
        echo -e "${YELLOW}Creating desktop shortcut...${NC}" | tee -a "$LOG_FILE"
        cat > /usr/share/applications/vorta.desktop << EOF
[Desktop Entry]
Type=Application
Name=Vorta
Comment=Backup client for Borg
Exec=vorta
Icon=${BUILD_DIR}/vorta/src/vorta/assets/icons/scalable/com.borgbase.Vorta.svg
Terminal=false
Categories=Utility;Archiving;
Keywords=backup;borg;
EOF
        check_status "Created desktop shortcut" || return 1
    fi

    # Verify installation
    if command_exists vorta; then
        echo -e "${GREEN}Vorta has been installed successfully from source.${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}Failed to verify Vorta installation. Check PATH or try reinstalling.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    return 0
}

# Function to configure BorgBackup defaults
configure_borg_defaults() {
    print_section_header "Configuring BorgBackup defaults"
    
    # Get the user for whom to configure Borg
    local user
    if [ "$(id -u)" -eq 0 ]; then
        user=$(get_real_user)
        if [ -z "$user" ] || [ "$user" = "root" ]; then
            echo -n "Enter the username for BorgBackup configuration: "
            read -r user
            if ! id "$user" >/dev/null 2>&1; then
                echo -e "${RED}User '$user' does not exist.${NC}" | tee -a "$LOG_FILE"
                return 1
            fi
        fi
    else
        user=$(whoami)
    fi
    
    local user_home=$(eval echo ~"$user")
    
    # Create Borg config directory if it doesn't exist
    sudo -u "$user" mkdir -p "$user_home/.config/borg"
    
    # Create a basic Borg config file if it doesn't exist
    if [ ! -f "$user_home/.config/borg/config" ]; then
        echo -e "${YELLOW}Creating default Borg configuration file...${NC}" | tee -a "$LOG_FILE"
        
        sudo -u "$user" cat > "$user_home/.config/borg/config" << EOF
# Default configuration for BorgBackup
# See https://borgbackup.readthedocs.io/en/stable/quickstart.html for more information

# Default location for repositories
BORG_REPO="/path/to/repo"

# Default compression level
BORG_COMPRESSION="lz4"

# Passphrase handling - for automated backups, consider setting this in your backup script
# BORG_PASSPHRASE="your-passphrase"

# Exclude these patterns by default
BORG_EXCLUDE_PATTERNS="
    /home/*/.cache/*
    /home/*/.local/share/Trash/*
    /var/cache/*
    /var/tmp/*
    /tmp/*
    *.pyc
    __pycache__
    *~
"
EOF
        check_status "Created default Borg configuration" || return 1
    else
        echo -e "${GREEN}Borg configuration file already exists. Skipping creation.${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Create a sample backup script if it doesn't exist
    if [ ! -f "$user_home/backup.sh" ]; then
        echo -e "${YELLOW}Creating sample backup script...${NC}" | tee -a "$LOG_FILE"
        
        sudo -u "$user" cat > "$user_home/backup.sh" << 'EOF'
#!/bin/bash
# Sample Borg backup script
# Make this script executable with: chmod +x backup.sh

# Load configuration
CONFIG_FILE="$HOME/.config/borg/config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Set variables
REPOSITORY="${BORG_REPO:-/path/to/repo}"
COMPRESSION="${BORG_COMPRESSION:-lz4}"
ARCHIVE_NAME="$(hostname)-$(date +%Y-%m-%d_%H:%M:%S)"

# Create backup
echo "Creating backup..."
borg create \
    --verbose \
    --progress \
    --compression "$COMPRESSION" \
    --exclude-caches \
    "$REPOSITORY::$ARCHIVE_NAME" \
    $HOME \
    --exclude "$HOME/.cache" \
    --exclude "$HOME/.local/share/Trash" \
    --exclude "*.pyc" \
    --exclude "__pycache__" \
    --exclude "*~"

# Prune old backups
echo "Pruning old backups..."
borg prune \
    --verbose \
    "$REPOSITORY" \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6

echo "Backup complete!"
EOF
        
        chmod +x "$user_home/backup.sh"
        chown "$user":"$user" "$user_home/backup.sh"
        check_status "Created sample backup script" || return 1
    else
        echo -e "${GREEN}Backup script already exists. Skipping creation.${NC}" | tee -a "$LOG_FILE"
    fi
    
    echo -e "${GREEN}BorgBackup configuration complete.${NC}" | tee -a "$LOG_FILE"
    echo -e "Edit ${YELLOW}$user_home/.config/borg/config${NC} to customize your settings." | tee -a "$LOG_FILE"
    echo -e "Run ${YELLOW}$user_home/backup.sh${NC} to test your backup." | tee -a "$LOG_FILE"
    
    return 0
}

# Function to configure scheduling for automated backups
configure_backup_scheduling() {
    print_section_header "Configuring automated backup schedule"

    # Get the user for whom to configure scheduling
    local user
    if [ "$(id -u)" -eq 0 ]; then
        user=$(get_real_user)
        if [ -z "$user" ] || [ "$user" = "root" ]; then
            echo -n "Enter the username for backup scheduling: "
            read -r user
            if ! id "$user" >/dev/null 2>&1; then
                echo -e "${RED}User '$user' does not exist.${NC}" | tee -a "$LOG_FILE"
                return 1
            fi
        fi
    else
        user=$(whoami)
    fi
    
    local user_home=$(eval echo ~"$user")
    
    # Check if backup script exists
    if [ ! -f "$user_home/backup.sh" ]; then
        echo -e "${RED}Backup script not found. Please run configure_borg_defaults first.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Ask for scheduling preference
    echo -e "${YELLOW}Backup scheduling options:${NC}" | tee -a "$LOG_FILE"
    echo "1. Daily (recommended for most users)" | tee -a "$LOG_FILE"
    echo "2. Weekly" | tee -a "$LOG_FILE"
    echo "3. Monthly" | tee -a "$LOG_FILE"
    echo "4. Custom schedule" | tee -a "$LOG_FILE"
    
    local schedule_choice
    read -p "Select scheduling option (1-4): " schedule_choice
    
    local cron_schedule
    case "$schedule_choice" in
        1) # Daily
            cron_schedule="0 3 * * *"  # 3:00 AM every day
            ;;
        2) # Weekly
            cron_schedule="0 3 * * 0"  # 3:00 AM every Sunday
            ;;
        3) # Monthly
            cron_schedule="0 3 1 * *"  # 3:00 AM on the 1st of each month
            ;;
        4) # Custom
            echo "Enter custom cron schedule (e.g., '0 3 * * *' for daily at 3:00 AM):"
            read -r cron_schedule
            ;;
        *)
            echo -e "${RED}Invalid choice. Using daily schedule as default.${NC}" | tee -a "$LOG_FILE"
            cron_schedule="0 3 * * *"
            ;;
    esac
    
    # Create temporary crontab file
    local temp_crontab=$(mktemp)
    
    # Get current crontab
    sudo -u "$user" crontab -l > "$temp_crontab" 2>/dev/null || echo "" > "$temp_crontab"
    
    # Check if backup job already exists
    if grep -q "backup.sh" "$temp_crontab"; then
        echo -e "${YELLOW}Backup job already exists in crontab. Updating...${NC}" | tee -a "$LOG_FILE"
        sed -i '/backup.sh/d' "$temp_crontab"
    fi
    
    # Add backup job to crontab
    echo "# Automated Borg backup" >> "$temp_crontab"
    echo "$cron_schedule $user_home/backup.sh > $user_home/backup.log 2>&1" >> "$temp_crontab"
    
    # Install new crontab
    sudo -u "$user" crontab "$temp_crontab"
    check_status "Backup schedule configured" || return 1
    
    # Clean up
    rm "$temp_crontab"
    
    echo -e "${GREEN}Automated backup scheduling complete.${NC}" | tee -a "$LOG_FILE"
    echo -e "Backups will run according to the selected schedule." | tee -a "$LOG_FILE"
    echo -e "Logs will be saved to ${YELLOW}$user_home/backup.log${NC}" | tee -a "$LOG_FILE"
    
    return 0
}