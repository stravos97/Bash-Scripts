#!/bin/bash
# utils.sh - Utility functions for Ubuntu system setup
# This module contains common functions used by other modules

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Text colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
LOG_FILE="/var/log/ubuntu-setup.log"
SCRIPT_NAME=$(basename "$0")
BUILD_DIR="/tmp/build_sources"
INSTALL_DIR="/opt"

# Initialize logging
init_logging() {
    # Create log directory if it doesn't exist
    local log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi
    
    # Log script start
    echo -e "\n${BLUE}=== Script execution started at $(date) ===${NC}" | tee -a "$LOG_FILE"
}

# Function to check if a command succeeded
check_status() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: $1${NC}" | tee -a "$LOG_FILE"
        echo "Command failed. Please check the output above for details." | tee -a "$LOG_FILE"
        return 1
    else
        echo -e "${GREEN}Success: $1${NC}" | tee -a "$LOG_FILE"
        return 0
    fi
}

# Function to get real username (the user who ran sudo)
get_real_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        logname 2>/dev/null || echo ""
    fi
}

# Function to check if running with sudo privileges
check_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}This script must be run with sudo privileges.${NC}" | tee -a "$LOG_FILE"
        echo -e "Please run: ${YELLOW}sudo bash $SCRIPT_NAME${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    return 0
}

# Function to validate username
validate_username() {
    local username="$1"
    # Check if username is valid
    if [[ ! "$username" =~ ^[a-z][-a-z0-9_]*$ ]]; then
        echo -e "${RED}Invalid username. Username must start with a letter and can only contain lowercase letters, numbers, hyphens, and underscores.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    # Check if username already exists
    if id "$username" >/dev/null 2>&1; then
        echo -e "${RED}User '$username' already exists.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    return 0
}

# Function to validate SSH public key
validate_ssh_key() {
    local key="$1"

    # Basic validation: check if it looks like an SSH public key
    if [[ ! "$key" =~ ^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)[[:space:]]+ ]]; then
        echo -e "${RED}The provided key doesn't appear to be a valid SSH public key.${NC}" | tee -a "$LOG_FILE"
        echo -e "A valid SSH public key should start with 'ssh-rsa', 'ssh-ed25519', etc." | tee -a "$LOG_FILE"
        return 1
    fi

    # Further validation: check number of parts
    local parts
    parts=$(echo "$key" | awk '{print NF}')
    if [ "$parts" -lt 2 ]; then
        echo -e "${RED}Invalid SSH key format.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    return 0
}

# Function to check if an SSH key already exists in authorized_keys
key_exists() {
    local key="$1"
    local auth_keys_file="$2"

    # Extract the key part (excluding type and comment)
    local key_part
    key_part=$(echo "$key" | awk '{print $2}')

    if [ -f "$auth_keys_file" ] && grep -q "$key_part" "$auth_keys_file"; then
        return 0  # Key exists
    else
        return 1  # Key doesn't exist
    fi
}

# Function to check if a setting exists in a config file
setting_exists() {
    local file="$1"
    local setting="$2"
    local value="$3"

    if [ -f "$file" ] && grep -q "^$setting[[:space:]]*$value" "$file"; then
        return 0  # Setting exists with the correct value
    else
        return 1  # Setting doesn't exist or has a different value
    fi
}

# Function to set configuration value in file (idempotent)
set_config_value() {
    local file="$1"
    local setting="$2"
    local value="$3"
    local comment="${4:-}"

    # Check if file exists
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: File $file does not exist${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    # If comment is provided, add it
    local setting_line="$setting $value"
    if [ -n "$comment" ]; then
        setting_line="$setting_line # $comment"
    fi

    # Check if setting already exists (with any value)
    if grep -q "^$setting[[:space:]]" "$file"; then
        # Setting exists, update its value if different
        if ! grep -q "^$setting[[:space:]]*$value" "$file"; then
            sed -i "s/^$setting[[:space:]].*/$setting_line/" "$file"
            echo "Updated setting $setting to $value in $file" | tee -a "$LOG_FILE"
        else
            echo "Setting $setting already has value $value in $file" | tee -a "$LOG_FILE"
        fi
    else
        # Setting doesn't exist, add it
        echo "$setting_line" >> "$file"
        echo "Added setting $setting with value $value to $file" | tee -a "$LOG_FILE"
    fi

    return 0
}

# Function to create a backup of a file if it doesn't already exist
backup_file() {
    local file="$1"
    local backup="${2:-$file.bak}"

    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: File $file does not exist${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    if [ ! -f "$backup" ]; then
        cp "$file" "$backup"
        echo "Created backup of $file at $backup" | tee -a "$LOG_FILE"
    else
        echo "Backup of $file already exists at $backup" | tee -a "$LOG_FILE"
    fi

    return 0
}

# Function to check if a package is installed
is_package_installed() {
    local package="$1"

    if dpkg -l | grep -q "^ii[[:space:]]*$package[[:space:]]"; then
        return 0  # Package is installed
    else
        return 1  # Package is not installed
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a firewall rule exists
firewall_rule_exists() {
    local rule="$1"

    if ufw status | grep -q "$rule"; then
        return 0  # Rule exists
    else
        return 1  # Rule doesn't exist
    fi
}

# Function to check if a software is already installed from source
source_installed() {
    local software="$1"
    local path

    case "$software" in
        vorta)
            # Check if Vorta is installed (either as a binary or as a Python module)
            if command_exists vorta || [ -d "/opt/vorta" ] || python3 -c "import vorta" &>/dev/null; then
                return 0  # Vorta is installed
            fi
            ;;
        *)
            echo "Unknown software: $software" | tee -a "$LOG_FILE"
            ;;
    esac

    return 1  # Software is not installed
}

# Function to check if a desktop environment is installed
is_desktop_installed() {
    # Check for common desktop packages or desktop-specific directories
    if is_package_installed "ubuntu-desktop" || \
       is_package_installed "xubuntu-desktop" || \
       is_package_installed "lubuntu-desktop" || \
       is_package_installed "kubuntu-desktop" || \
       is_package_installed "xfce4" || \
       is_package_installed "lxde" || \
       is_package_installed "mate-desktop-environment" || \
       is_package_installed "cinnamon-desktop-environment" || \
       [ -d "/usr/share/xsessions" ]; then
        return 0  # A desktop environment is installed
    else
        return 1  # No desktop environment is installed
    fi
}

# Function to detect the currently installed desktop environment
detect_desktop_environment() {
    if [ -f /usr/bin/gnome-session ]; then
        echo "GNOME"
    elif [ -f /usr/bin/xfce4-session ]; then
        echo "XFCE"
    elif [ -f /usr/bin/mate-session ]; then
        echo "MATE"
    elif [ -f /usr/bin/cinnamon-session ]; then
        echo "Cinnamon"
    elif [ -f /usr/bin/startplasma-x11 ]; then
        echo "KDE Plasma"
    elif [ -f /usr/bin/lxsession ]; then
        echo "LXDE"
    else
        echo "Unknown"
    fi
}

# Get Ubuntu version
get_ubuntu_version() {
    lsb_release -rs
}

# Print section header
print_section_header() {
    local title="$1"
    echo -e "\n${BLUE}=== $title ===${NC}" | tee -a "$LOG_FILE"
}

# Ask yes/no question and return answer
ask_yes_no() {
    local prompt="$1"
    local response
    
    echo -e "${BLUE}$prompt (y/n)${NC}" | tee -a "$LOG_FILE"
    read -r response
    
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        return 0  # Yes
    else
        return 1  # No
    fi
}

# Create necessary directories for the script
create_directories() {
    # Create build directory if it doesn't exist
    mkdir -p "$BUILD_DIR"
    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
}

# Export utility functions
export -f check_status
export -f get_real_user
export -f check_sudo
export -f validate_username
export -f validate_ssh_key
export -f key_exists
export -f setting_exists
export -f set_config_value
export -f backup_file
export -f is_package_installed
export -f command_exists
export -f firewall_rule_exists
export -f source_installed
export -f is_desktop_installed
export -f detect_desktop_environment
export -f get_ubuntu_version
export -f print_section_header
export -f ask_yes_no
export -f create_directories

# Initialize variables
create_directories