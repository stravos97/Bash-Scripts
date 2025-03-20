#!/bin/bash

# Idempotent Ubuntu System Setup Script
# This script will:
# 1. Update your Ubuntu system packages
# 2. Install Borg backup and Vorta (from source)
# 3. Set up xRDP for Windows Remote Desktop connections
# 4. Optionally create a new user with sudo privileges
# 5. Configure SSH with public key authentication
# 6. Install a lightweight desktop environment if needed (from standard repos)
#
# This script is idempotent - it can be run multiple times safely

# Set text colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set script name for logging
SCRIPT_NAME=$(basename "$0")

# Enable logging
LOG_FILE="/var/log/${SCRIPT_NAME%.*}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo -e "\n${BLUE}=== Script execution started at $(date) ===${NC}"

# Ensure script is run with sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run with sudo privileges.${NC}"
    echo -e "Please run: ${YELLOW}sudo bash $0${NC}"
    exit 1
fi

# Initialize variables
ubuntu_version=$(lsb_release -rs)
is_desktop=false
script_path=$(realpath "$0")
build_dir="/tmp/build_sources"
install_dir="/opt"

# Function to check if a command succeeded
check_status() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: $1${NC}"
        echo "Command failed. Please check the output above for details."
        exit 1
    else
        echo -e "${GREEN}Success: $1${NC}"
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

# Function to validate username
validate_username() {
    local username="$1"
    # Check if username is valid
    if [[ ! "$username" =~ ^[a-z][-a-z0-9_]*$ ]]; then
        echo -e "${RED}Invalid username. Username must start with a letter and can only contain lowercase letters, numbers, hyphens, and underscores.${NC}"
        return 1
    fi

    # Check if username already exists
    if id "$username" >/dev/null 2>&1; then
        echo -e "${RED}User '$username' already exists.${NC}"
        return 1
    fi

    return 0
}

# Function to validate SSH public key
validate_ssh_key() {
    local key="$1"

    # Basic validation: check if it looks like an SSH public key
    if [[ ! "$key" =~ ^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)[[:space:]]+ ]]; then
        echo -e "${RED}The provided key doesn't appear to be a valid SSH public key.${NC}"
        echo -e "A valid SSH public key should start with 'ssh-rsa', 'ssh-ed25519', etc."
        return 1
    fi

    # Further validation: check number of parts
    local parts
    parts=$(echo "$key" | awk '{print NF}')
    if [ "$parts" -lt 2 ]; then
        echo -e "${RED}Invalid SSH key format.${NC}"
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
        echo -e "${RED}Error: File $file does not exist${NC}"
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
            echo "Updated setting $setting to $value in $file"
        else
            echo "Setting $setting already has value $value in $file"
        fi
    else
        # Setting doesn't exist, add it
        echo "$setting_line" >> "$file"
        echo "Added setting $setting with value $value to $file"
    fi

    return 0
}

# Function to create a backup of a file if it doesn't already exist
backup_file() {
    local file="$1"
    local backup="${2:-$file.bak}"

    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: File $file does not exist${NC}"
        return 1
    fi

    if [ ! -f "$backup" ]; then
        cp "$file" "$backup"
        echo "Created backup of $file at $backup"
    else
        echo "Backup of $file already exists at $backup"
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
# This checks specific binaries or directories that would be created by source installation
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
            echo "Unknown software: $software"
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

# Function to install Vorta from source
install_vorta_from_source() {
    echo -e "\n${BLUE}=== Installing Vorta from source ===${NC}"

    # Check if Vorta is already installed
    if source_installed "vorta"; then
        echo -e "${GREEN}Vorta is already installed. Skipping installation.${NC}"
        return 0
    fi

    # Install build dependencies
    echo -e "${YELLOW}Installing build dependencies...${NC}"
    apt install -y git python3-pip python3-dev python3-setuptools python3-wheel python3-all \
                   python3-pyqt5 python3-pyqt5.qtsvg libfuse-dev pkg-config
    check_status "Installed build dependencies"

    # Create build directory if it doesn't exist
    mkdir -p "$build_dir"
    cd "$build_dir" || exit

    # Clone Vorta repository if it doesn't exist
    if [ ! -d "$build_dir/vorta" ]; then
        echo -e "${YELLOW}Cloning Vorta repository...${NC}"
        git clone https://github.com/borgbase/vorta.git
        check_status "Cloned Vorta repository"
    else
        echo -e "${GREEN}Vorta repository already exists. Updating...${NC}"
        cd "$build_dir/vorta" || exit
        git pull
        check_status "Updated Vorta repository"
    fi

    cd "$build_dir/vorta" || exit

    # Install Vorta
    echo -e "${YELLOW}Installing Vorta...${NC}"
    pip3 install --upgrade .
    check_status "Installed Vorta"

    # Create desktop shortcut
    if [ ! -f "/usr/share/applications/vorta.desktop" ]; then
        echo -e "${YELLOW}Creating desktop shortcut...${NC}"
        cat > /usr/share/applications/vorta.desktop << EOF
[Desktop Entry]
Type=Application
Name=Vorta
Comment=Backup client for Borg
Exec=vorta
Icon=${build_dir}/vorta/src/vorta/assets/icons/scalable/com.borgbase.Vorta.svg
Terminal=false
Categories=Utility;Archiving;
Keywords=backup;borg;
EOF
        check_status "Created desktop shortcut"
    fi

    echo -e "${GREEN}Vorta has been installed successfully from source.${NC}"
    return 0
}

# Function to install a desktop environment
install_desktop_environment() {
    echo -e "\n${BLUE}=== Installing Desktop Environment ===${NC}"

    local de_options=(
        "XFCE (Lightweight and stable)"
        "LXDE (Very lightweight, minimal)"
        "MATE (Traditional desktop, medium weight)"
        "Cinnamon (Modern features, heavier)"
        "GNOME (Ubuntu default, resource-intensive)"
        "KDE Plasma (Feature-rich, customizable, heavier)"
    )

    echo -e "${YELLOW}Available desktop environments:${NC}"
    for i in "${!de_options[@]}"; do
        echo "$((i+1)). ${de_options[$i]}"
    done

    local valid_choice=false
    local choice

    while [ "$valid_choice" = false ]; do
        echo -n "Select a desktop environment to install (1-${#de_options[@]}): "
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#de_options[@]}" ]; then
            valid_choice=true
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#de_options[@]}.${NC}"
        fi
    done

    # Adjust for zero-based indexing
    choice=$((choice-1))

    # Update package repositories first
    apt update
    check_status "Repository information updated"

    # Install based on selection
    case $choice in
        0) # XFCE
            echo -e "${YELLOW}Installing XFCE desktop environment...${NC}"
            apt install xfce4 xfce4-goodies -y
            check_status "XFCE desktop environment installed"
            # Set XFCE as default desktop
            update-alternatives --set x-session-manager /usr/bin/xfce4-session 2>/dev/null || true
            ;;
        1) # LXDE
            echo -e "${YELLOW}Installing LXDE desktop environment...${NC}"
            apt install lxde -y
            check_status "LXDE desktop environment installed"
            # Set LXDE as default desktop
            update-alternatives --set x-session-manager /usr/bin/lxsession 2>/dev/null || true
            ;;
        2) # MATE
            echo -e "${YELLOW}Installing MATE desktop environment...${NC}"
            apt install mate-desktop-environment mate-desktop-environment-extras -y
            check_status "MATE desktop environment installed"
            # Set MATE as default desktop
            update-alternatives --set x-session-manager /usr/bin/mate-session 2>/dev/null || true
            ;;
        3) # Cinnamon
            echo -e "${YELLOW}Installing Cinnamon desktop environment...${NC}"
            apt install cinnamon-desktop-environment -y
            check_status "Cinnamon desktop environment installed"
            # Set Cinnamon as default desktop
            update-alternatives --set x-session-manager /usr/bin/cinnamon-session 2>/dev/null || true
            ;;
        4) # GNOME
            echo -e "${YELLOW}Installing GNOME desktop environment...${NC}"
            apt install ubuntu-desktop -y
            check_status "GNOME desktop environment installed"
            # Ubuntu already sets GNOME as default
            ;;
        5) # KDE Plasma
            echo -e "${YELLOW}Installing KDE Plasma desktop environment...${NC}"
            apt install kde-plasma-desktop -y
            check_status "KDE Plasma desktop environment installed"
            # Set KDE as default desktop
            update-alternatives --set x-session-manager /usr/bin/startplasma-x11 2>/dev/null || true
            ;;
    esac

    # Install additional components that are useful for any desktop
    echo -e "${YELLOW}Installing additional desktop components...${NC}"
    apt install xdg-utils xorg lightdm -y
    check_status "Additional desktop components installed"

    # Configure LightDM (if installed)
    if is_package_installed "lightdm"; then
        echo -e "${YELLOW}Setting LightDM as the default display manager...${NC}"
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
    echo -e "${YELLOW}Installing common fonts and themes...${NC}"
    apt install fonts-liberation2 fonts-noto arc-theme papirus-icon-theme -y
    check_status "Fonts and themes installed"

    # Install web browser if not present
    if ! is_package_installed "firefox"; then
        echo -e "${YELLOW}Installing Firefox web browser...${NC}"
        apt install firefox -y
        check_status "Firefox installed"
    fi

    echo -e "${GREEN}Desktop environment installation complete!${NC}"
    echo "You will be able to select your desktop environment at the login screen."

    # Update desktop detection variable
    is_desktop=true

    return 0
}

# Function to set up SSH with public key authentication
setup_ssh_key() {
    local username="$1"
    local key_source="$2" # "paste" or "file"
    local user_home

    # Get user's home directory
    user_home=$(eval echo ~"$username")

    echo -e "\n${BLUE}=== Setting up SSH Public Key Authentication for user '$username' ===${NC}"

    # Create .ssh directory if it doesn't exist
    if [ ! -d "$user_home/.ssh" ]; then
        mkdir -p "$user_home/.ssh"
        check_status "Created .ssh directory"
    else
        echo -e "${GREEN}.ssh directory already exists.${NC}"
    fi

    local ssh_key=""

    if [ "$key_source" = "paste" ]; then
        # Get public key from user input
        echo -e "${YELLOW}Please paste your SSH public key (starts with ssh-rsa, ssh-ed25519, etc.):${NC}"
        read -r ssh_key

        # Validate the key
        if ! validate_ssh_key "$ssh_key"; then
            echo -e "${RED}SSH key setup failed.${NC}"
            return 1
        fi
    elif [ "$key_source" = "file" ]; then
        echo -e "${YELLOW}Enter the path to your public key file:${NC}"
        read -r key_path

        if [ ! -f "$key_path" ]; then
            echo -e "${RED}File not found: $key_path${NC}"
            return 1
        fi

        ssh_key=$(cat "$key_path")

        # Validate the key
        if ! validate_ssh_key "$ssh_key"; then
            echo -e "${RED}SSH key setup failed.${NC}"
            return 1
        fi
    else
        echo -e "${RED}Invalid key source.${NC}"
        return 1
    fi

    # Check if authorized_keys file exists
    local auth_keys_file="$user_home/.ssh/authorized_keys"
    if [ ! -f "$auth_keys_file" ]; then
        touch "$auth_keys_file"
        echo "Created new authorized_keys file"
    fi

    # Check if key already exists in authorized_keys
    if key_exists "$ssh_key" "$auth_keys_file"; then
        echo -e "${GREEN}SSH key already exists in authorized_keys. Skipping addition.${NC}"
    else
        # Add key to authorized_keys
        echo "$ssh_key" >> "$auth_keys_file"
        check_status "Added SSH key to authorized_keys"
    fi

    # Fix permissions
    chmod 700 "$user_home/.ssh"
    chmod 600 "$auth_keys_file"
    chown -R "$username":"$username" "$user_home/.ssh"
    check_status "Set correct permissions for SSH files"

    echo -e "${GREEN}SSH public key authentication configured successfully for user '$username'.${NC}"

    return 0
}

# Function to install and configure SSH server
setup_ssh_server() {
    echo -e "\n${BLUE}=== Installing and Configuring SSH Server ===${NC}"

    # Install OpenSSH server if not already installed
    if ! is_package_installed "openssh-server"; then
        apt install openssh-server -y
        check_status "OpenSSH server installed"
    else
        echo -e "${GREEN}OpenSSH server is already installed.${NC}"
    fi

    # Backup the SSH config file if backup doesn't exist
    backup_file "/etc/ssh/sshd_config"

    # Enhance SSH security configurations
    echo -e "${YELLOW}Configuring SSH for enhanced security...${NC}"

    # Set configuration values idempotently
    set_config_value "/etc/ssh/sshd_config" "PasswordAuthentication" "yes"
    set_config_value "/etc/ssh/sshd_config" "PubkeyAuthentication" "yes"
    set_config_value "/etc/ssh/sshd_config" "PermitRootLogin" "prohibit-password"

    # Open SSH port in firewall if it's not already open
    if command -v ufw &> /dev/null; then
        if ! firewall_rule_exists "22/tcp"; then
            ufw allow ssh
            check_status "Firewall configured to allow SSH connections"
        else
            echo -e "${GREEN}Firewall already allows SSH connections.${NC}"
        fi
    fi

    # Check if SSH service needs to be restarted due to config changes
    if systemctl is-active sshd &>/dev/null; then
        systemctl restart sshd
        check_status "SSH service restarted"
    else
        systemctl start sshd
        check_status "SSH service started"
    fi

    return 0
}

# Function to create a new user with sudo privileges
create_new_user() {
    echo -e "\n${BLUE}=== Creating New User ===${NC}"

    # Get username
    local valid_username=false
    while [ "$valid_username" = false ]; do
        echo -n "Enter new username: "
        read -r new_username

        if validate_username "$new_username"; then
            valid_username=true
        fi
    done

    # Get password
    echo -n "Enter password for $new_username: "
    read -s new_password
    echo

    echo -n "Confirm password: "
    read -s confirm_password
    echo

    if [ "$new_password" != "$confirm_password" ]; then
        echo -e "${RED}Passwords do not match.${NC}"
        return 1
    fi

    # Create user
    echo -e "\n${YELLOW}Creating user '$new_username' with home directory...${NC}"
    useradd -m -s /bin/bash "$new_username"
    echo "$new_username:$new_password" | chpasswd

    # Add user to sudo group
    echo -e "${YELLOW}Adding '$new_username' to sudo group...${NC}"
    usermod -aG sudo "$new_username"

    # Copy script to new user's home directory if it's not already there
    local new_user_script="/home/$new_username/$(basename "$script_path")"
    if [ ! -f "$new_user_script" ]; then
        cp "$script_path" "$new_user_script"
        chown "$new_username":"$new_username" "$new_user_script"
        chmod +x "$new_user_script"
        echo -e "The setup script has been copied to ${YELLOW}$new_user_script${NC}"
    else
        echo -e "${GREEN}Script already exists at $new_user_script${NC}"
    fi

    echo -e "${GREEN}User '$new_username' has been created successfully with sudo privileges.${NC}"

    # Set up SSH key for the new user
    echo -n "Would you like to set up SSH public key authentication for the new user? (y/n): "
    read -r setup_ssh

    if [[ "$setup_ssh" == "y" || "$setup_ssh" == "Y" ]]; then
        echo -n "How would you like to provide the SSH key? (paste/file): "
        read -r key_method

        setup_ssh_key "$new_username" "$key_method"
    fi

    # Provide instructions for the new user
    echo -e "${YELLOW}Setup complete for new user '$new_username'.${NC}"
    echo -e "${GREEN}To continue with system setup:${NC}"
    echo -e "1. Log out of this session"
    echo -e "2. Log in as user '$new_username'"
    echo -e "3. Run the script with: ${YELLOW}sudo bash $new_user_script${NC}"

    echo -n "Would you like to continue system setup with the current user instead? (y/n): "
    read -r continue_current

    if [[ "$continue_current" != "y" && "$continue_current" != "Y" ]]; then
        echo -e "${GREEN}Exiting. Please log in as '$new_username' to complete setup.${NC}"
        exit 0
    fi

    return 0
}

# Function to configure xRDP for a user
configure_xrdp_for_user() {
    local username="$1"
    local user_home

    user_home=$(eval echo ~"$username")

    if [ ! -d "$user_home" ]; then
        echo -e "${RED}Home directory for user $username does not exist.${NC}"
        return 1
    fi

    echo -e "Configuring xRDP session for user ${YELLOW}$username${NC}"

    # Check if .xsession already exists
    if [ -f "$user_home/.xsession" ]; then
        echo -e "${GREEN}.xsession file already exists for user $username. Checking configuration...${NC}"
        # We could add more sophisticated checks here if needed
    else
        # Detect desktop environment and create appropriate .xsession file
        if [ -f /usr/bin/gnome-session ]; then
            echo "GNOME detected, configuring xRDP for GNOME..."

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for GNOME
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg
exec gnome-session
EOF
        elif [ -f /usr/bin/xfce4-session ]; then
            echo "XFCE detected, configuring xRDP for XFCE..."

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for XFCE
startxfce4
EOF
        elif [ -f /usr/bin/mate-session ]; then
            echo "MATE detected, configuring xRDP for MATE..."

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for MATE
mate-session
EOF
        elif [ -f /usr/bin/cinnamon-session ]; then
            echo "Cinnamon detected, configuring xRDP for Cinnamon..."

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for Cinnamon
cinnamon-session
EOF
        elif [ -f /usr/bin/startplasma-x11 ]; then
            echo "KDE Plasma detected, configuring xRDP for KDE..."

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for KDE Plasma
export DESKTOP_SESSION=plasma
startplasma-x11
EOF
        elif [ -f /usr/bin/lxsession ]; then
            echo "LXDE detected, configuring xRDP for LXDE..."

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for LXDE
lxsession
EOF
        else
            echo "No specific desktop environment detected, using default xRDP configuration."
            return 0
        fi

        # Set correct permissions for .xsession file
        chmod +x "$user_home/.xsession"
        chown "$username":"$username" "$user_home/.xsession"
        echo "Session configuration file created at $user_home/.xsession"
    fi

    return 0
}

# Function to install BorgBackup from source
install_borg_from_source() {
    echo -e "\n${BLUE}=== Installing BorgBackup from source ===${NC}"

    # Check if Borg is already installed
    if command_exists borg; then
        echo -e "${GREEN}BorgBackup is already installed.${NC}"
        return 0
    fi

    # Install build dependencies
    echo -e "${YELLOW}Installing build dependencies...${NC}"
    apt install -y python3-dev python3-pip pkg-config libacl1-dev libssl-dev \
                   liblz4-dev libzstd-dev libxxhash-dev
    check_status "Installed build dependencies"

    # Install Borg using pip
    echo -e "${YELLOW}Installing BorgBackup...${NC}"
    pip3 install --upgrade borgbackup
    check_status "Installed BorgBackup"

    echo -e "${GREEN}BorgBackup has been installed successfully from source.${NC}"
    return 0
}

# Check if we're running on a desktop system
if is_desktop_installed; then
    is_desktop=true
    echo -e "${GREEN}Desktop environment detected: $(detect_desktop_environment)${NC}"
fi

# Create build directories
mkdir -p "$build_dir"

# Main Setup Options
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     UBUNTU SYSTEM SETUP & CONFIGURATION     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"

# Ask if desktop environment should be installed if none detected
if ! $is_desktop; then
    echo -e "${BLUE}No desktop environment detected. Would you like to install one? (y/n)${NC}"
    read -r install_desktop

    if [[ "$install_desktop" == "y" || "$install_desktop" == "Y" ]]; then
        install_desktop_environment
    else
        echo -e "${YELLOW}Continuing without desktop environment installation...${NC}"
    fi
else
    echo -e "${BLUE}Would you like to install a different desktop environment? (y/n)${NC}"
    read -r change_desktop

    if [[ "$change_desktop" == "y" || "$change_desktop" == "Y" ]]; then
        install_desktop_environment
    fi
fi

# Ask if SSH server should be set up
echo -e "${BLUE}Would you like to set up the SSH server? (y/n)${NC}"
read -r setup_ssh_now

if [[ "$setup_ssh_now" == "y" || "$setup_ssh_now" == "Y" ]]; then
    setup_ssh_server
fi

# Ask if a new user needs to be set up
echo -e "${BLUE}Would you like to set up a new user? (y/n)${NC}"
read -r setup_new_user

if [[ "$setup_new_user" == "y" || "$setup_new_user" == "Y" ]]; then
    create_new_user
    if [ $? -ne 0 ]; then
        echo -e "${RED}User creation failed. Continuing with system updates using current user.${NC}"
    fi
fi

# Ask if SSH key should be set up for current user
REAL_USER=$(get_real_user)
if [ -n "$REAL_USER" ] && [[ "$REAL_USER" != "root" ]]; then
    echo -e "${BLUE}Would you like to set up SSH public key authentication for user '$REAL_USER'? (y/n)${NC}"
    read -r setup_ssh_current

    if [[ "$setup_ssh_current" == "y" || "$setup_ssh_current" == "Y" ]]; then
        echo -n "How would you like to provide the SSH key? (paste/file): "
        read -r key_method

        setup_ssh_key "$REAL_USER" "$key_method"
    fi
fi

echo -e "\n${BLUE}=== Ubuntu System Information ===${NC}"
echo -e "Ubuntu Version: ${YELLOW}$ubuntu_version${NC}"

# Show desktop environment info
if is_desktop_installed; then
    echo -e "Desktop Environment: ${YELLOW}$(detect_desktop_environment)${NC}"
else
    echo -e "Desktop Environment: ${YELLOW}Not installed${NC}"
fi
echo ""

echo -e "${BLUE}=== Updating system packages ===${NC}"
apt update
check_status "System package list updated"
apt upgrade -y
check_status "System packages upgraded"

echo -e "${BLUE}=== Installing BorgBackup from source ===${NC}"
install_borg_from_source

# Ask if Vorta should be installed
if is_desktop_installed || [[ "$install_desktop" == "y" && "$install_desktop" == "Y" ]]; then
    echo -e "${BLUE}Would you like to install Vorta (GUI frontend for BorgBackup)? (y/n)${NC}"
    read -r install_vorta

    if [[ "$install_vorta" == "y" || "$install_vorta" == "Y" ]]; then
        install_vorta_from_source
    fi
else
    echo -e "${YELLOW}No desktop environment detected. Skipping Vorta installation.${NC}"
fi

echo -e "${BLUE}=== Setting up Remote Desktop Server (xRDP) ===${NC}"
# Install xRDP if not already installed
if ! is_package_installed "xrdp"; then
    apt install xrdp -y
    check_status "xRDP installed"
else
    echo -e "${GREEN}xRDP is already installed.${NC}"
fi

# Install additional dependencies if not already installed
if ! is_package_installed "xorgxrdp"; then
    apt install xorgxrdp -y
    check_status "xorgxrdp installed"
else
    echo -e "${GREEN}xorgxrdp is already installed.${NC}"
fi

# Configure xRDP for better compatibility
echo -e "${BLUE}=== Configuring xRDP for optimal performance ===${NC}"
# Create backup of xrdp.ini if it doesn't exist
backup_file "/etc/xrdp/xrdp.ini"

# Update xRDP config for better performance (idempotently)
set_config_value "/etc/xrdp/xrdp.ini" "max_bpp" "24"
set_config_value "/etc/xrdp/xrdp.ini" "crypt_level" "low"

# Fix known issues with desktop environments
if [ -n "$REAL_USER" ]; then
    configure_xrdp_for_user "$REAL_USER"
fi

# Create a polkit rule to allow anyone to restart xrdp if it doesn't exist
POLKIT_FILE="/etc/polkit-1/localauthority/50-local.d/45-allow-xrdp.pkla"
if [ ! -f "$POLKIT_FILE" ]; then
    # Ensure directory exists
    mkdir -p "/etc/polkit-1/localauthority/50-local.d"

    cat > "$POLKIT_FILE" << EOF
[Allow Restart XRDP]
Identity=unix-group:sudo
Action=org.freedesktop.systemd1.manage-units
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF
    check_status "Created polkit rule for xRDP"
else
    echo -e "${GREEN}Polkit rule for xRDP already exists.${NC}"
fi

# Enable xRDP service to start on boot (idempotent)
systemctl enable xrdp
check_status "xRDP enabled at startup"

# Restart xRDP service if it's running, otherwise start it
if systemctl is-active xrdp &>/dev/null; then
    systemctl restart xrdp
    check_status "xRDP service restarted"
else
    systemctl start xrdp
    check_status "xRDP service started"
fi

# Configure firewall to allow RDP connections (port 3389) if not already allowed
if command -v ufw &> /dev/null; then
    if ! firewall_rule_exists "3389/tcp"; then
        ufw allow 3389/tcp
        check_status "Firewall configured to allow RDP connections on port 3389"
    else
        echo -e "${GREEN}Firewall already allows RDP connections.${NC}"
    fi
fi

# Get the IP address for connecting
ip_address=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${BLUE}========================================================${NC}"
echo -e "${GREEN}Installation complete! Your system is now set up with:${NC}"
echo "1. Updated Ubuntu packages"

# List installed desktop environment if applicable
if is_desktop_installed; then
    echo "2. Desktop Environment: $(detect_desktop_environment)"
    echo "   (You can change this at the login screen)"
    next_number=3
else
    next_number=2
fi

echo "$next_number. BorgBackup (command-line) for backups"
if command_exists vorta; then
    echo "   and Vorta (GUI) for visual backup management"
fi
next_number=$((next_number+1))

echo "$next_number. xRDP server for Windows Remote Desktop connections"
next_number=$((next_number+1))

if is_package_installed "openssh-server"; then
    echo "$next_number. SSH server for secure shell access"
    next_number=$((next_number+1))
fi

if [[ "$setup_new_user" == "y" || "$setup_new_user" == "Y" ]]; then
    echo "$next_number. New user setup with sudo privileges"
fi

echo ""
echo -e "${YELLOW}Remote Access Options:${NC}"
echo -e "${CYAN}Windows Remote Desktop:${NC}"
echo "1. Open Remote Desktop Connection (mstsc.exe)"
echo "2. Enter the IP address of this machine: $ip_address"
echo "3. Log in with your Ubuntu username and password"
echo ""
if is_package_installed "openssh-server"; then
    echo -e "${CYAN}SSH Access:${NC}"
    echo "For Windows: Use PuTTY or Windows Terminal with command:"
    echo "  ssh username@$ip_address"
    echo ""
    echo "For Linux/Mac: Use Terminal with command:"
    echo "  ssh username@$ip_address"
    echo ""
fi
if command_exists vorta; then
    echo -e "${YELLOW}To start using Vorta for backups:${NC}"
    echo "1. Open Vorta from your applications menu"
    echo "2. Set up a new repository and start creating backups"
    echo ""
    echo "For more information on using Vorta, visit:"
    echo "https://vorta.borgbase.com/usage/"
fi
echo ""
echo -e "${YELLOW}For more information on using Borg Backup, visit:${NC}"
echo "https://borgbackup.readthedocs.io/en/stable/quickstart.html"
echo ""
echo -e "${YELLOW}If you experience any issues with Remote Desktop:${NC}"
echo "1. Ensure your firewall allows connections to port 3389"
echo "2. Try reconnecting after a system restart"
echo "3. Check /var/log/xrdp.log for error messages"
echo -e "${BLUE}========================================================${NC}"

echo -e "\n${BLUE}=== Script execution completed at $(date) ===${NC}"
echo -e "${GREEN}Log file created at: $LOG_FILE${NC}"
