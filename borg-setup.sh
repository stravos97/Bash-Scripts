#!/bin/bash

# Ubuntu System Update, Backup Tools, Remote Desktop, and User Setup Script
# This script will:
# 1. Update your Ubuntu system packages
# 2. Install Borg backup and Vorta (GUI frontend)
# 3. Set up xRDP for Windows Remote Desktop connections
# 4. Optionally create a new user with sudo privileges

# Set text colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure script is run with sudo privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run with sudo privileges.${NC}"
    echo -e "Please run: ${YELLOW}sudo bash $0${NC}"
    exit 1
fi

# Initialize variables
install_vorta="y"  # Default to yes
ubuntu_version=$(lsb_release -rs)
is_desktop=false
script_path=$(realpath "$0")

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

    # Copy script to new user's home directory
    cp "$script_path" "/home/$new_username/"
    chown "$new_username":"$new_username" "/home/$new_username/$(basename "$script_path")"
    chmod +x "/home/$new_username/$(basename "$script_path")"

    echo -e "${GREEN}User '$new_username' has been created successfully with sudo privileges.${NC}"
    echo -e "The setup script has been copied to ${YELLOW}/home/$new_username/$(basename "$script_path")${NC}"

    # Provide instructions for the new user
    echo -e "${YELLOW}Setup complete for new user '$new_username'.${NC}"
    echo -e "${GREEN}To continue with system setup:${NC}"
    echo -e "1. Log out of this session"
    echo -e "2. Log in as user '$new_username'"
    echo -e "3. Run the script with: ${YELLOW}sudo bash /home/$new_username/$(basename "$script_path")${NC}"

    echo -n "Would you like to continue system setup with the current user instead? (y/n): "
    read -r continue_current

    if [[ "$continue_current" != "y" && "$continue_current" != "Y" ]]; then
        echo -e "${GREEN}Exiting. Please log in as '$new_username' to complete setup.${NC}"
        exit 0
    fi

    return 0
}

# Check if we're running on a desktop system
if [ -n "$XDG_CURRENT_DESKTOP" ] || [ -d "/usr/share/xsessions" ]; then
    is_desktop=true
fi

# Ask if a new user needs to be set up first
echo -e "${BLUE}Would you like to set up a new user before proceeding with system updates? (y/n)${NC}"
read -r setup_new_user

if [[ "$setup_new_user" == "y" || "$setup_new_user" == "Y" ]]; then
    create_new_user
    if [ $? -ne 0 ]; then
        echo -e "${RED}User creation failed. Continuing with system updates using current user.${NC}"
    fi
fi

echo -e "\n${BLUE}=== Ubuntu System Information ===${NC}"
echo -e "Ubuntu Version: ${YELLOW}$ubuntu_version${NC}"
echo -e "Desktop Environment: ${YELLOW}$(if $is_desktop; then echo "Detected"; else echo "Not detected (server/headless)"; fi)${NC}"
echo ""

echo -e "${BLUE}=== Updating system packages ===${NC}"
apt update
check_status "System package list updated"
apt upgrade -y
check_status "System packages upgraded"

echo -e "${BLUE}=== Installing Borg Backup ===${NC}"
apt install borgbackup -y
check_status "Borg Backup installed"

if ! $is_desktop; then
    echo -e "${YELLOW}Warning: No desktop environment detected. Vorta requires a GUI.${NC}"
    echo -n "Would you like to install Vorta anyway? (y/n): "
    read -r install_vorta
fi

if [[ "$install_vorta" == "y" || "$install_vorta" == "Y" ]]; then
    echo -e "${BLUE}=== Installing Vorta Backup GUI ===${NC}"
    # Install software-properties-common if not already installed
    apt install software-properties-common -y

    # Add Vorta PPA
    add-apt-repository ppa:vorta/stable -y
    check_status "Vorta repository added"

    apt update
    apt install vorta -y
    check_status "Vorta installed"
fi

echo -e "${BLUE}=== Setting up Remote Desktop Server (xRDP) ===${NC}"
apt install xrdp -y
check_status "xRDP installed"

# Install additional dependencies
apt install xorgxrdp -y

# Configure xRDP for better compatibility
echo -e "${BLUE}=== Configuring xRDP for optimal performance ===${NC}"
# Create backup of xrdp.ini
cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.bak

# Update xRDP config for better performance
sed -i 's/max_bpp=32/max_bpp=24/g' /etc/xrdp/xrdp.ini
sed -i 's/crypt_level=high/crypt_level=low/g' /etc/xrdp/xrdp.ini

# Fix known issues with desktop environments
REAL_USER=$(get_real_user)

if [ -n "$REAL_USER" ]; then
    REAL_USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

    if [ -d "$REAL_USER_HOME" ]; then
        echo -e "Configuring xRDP session for user ${YELLOW}$REAL_USER${NC}"

        # Detect desktop environment
        if [ -f /usr/bin/gnome-session ]; then
            echo "GNOME detected, configuring xRDP for GNOME..."

            # Create a .xsession file
            cat > "$REAL_USER_HOME/.xsession" << EOF
#!/bin/sh
# xRDP session startup for GNOME
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg
exec gnome-session
EOF
        elif [ -f /usr/bin/xfce4-session ]; then
            echo "XFCE detected, configuring xRDP for XFCE..."

            # Create a .xsession file
            cat > "$REAL_USER_HOME/.xsession" << EOF
#!/bin/sh
# xRDP session startup for XFCE
startxfce4
EOF
        elif [ -f /usr/bin/mate-session ]; then
            echo "MATE detected, configuring xRDP for MATE..."

            # Create a .xsession file
            cat > "$REAL_USER_HOME/.xsession" << EOF
#!/bin/sh
# xRDP session startup for MATE
mate-session
EOF
        elif [ -f /usr/bin/cinnamon-session ]; then
            echo "Cinnamon detected, configuring xRDP for Cinnamon..."

            # Create a .xsession file
            cat > "$REAL_USER_HOME/.xsession" << EOF
#!/bin/sh
# xRDP session startup for Cinnamon
cinnamon-session
EOF
        elif [ -f /usr/bin/startplasma-x11 ]; then
            echo "KDE Plasma detected, configuring xRDP for KDE..."

            # Create a .xsession file
            cat > "$REAL_USER_HOME/.xsession" << EOF
#!/bin/sh
# xRDP session startup for KDE Plasma
export DESKTOP_SESSION=plasma
startplasma-x11
EOF
        else
            echo "No specific desktop environment detected, using default xRDP configuration."
        fi

        # Set correct permissions if a .xsession file was created
        if [ -f "$REAL_USER_HOME/.xsession" ]; then
            chmod +x "$REAL_USER_HOME/.xsession"
            chown "$REAL_USER":"$REAL_USER" "$REAL_USER_HOME/.xsession"
            echo "Session configuration file created at $REAL_USER_HOME/.xsession"
        fi
    fi
fi

# Create a polkit rule to allow anyone to restart xrdp
cat > /etc/polkit-1/localauthority/50-local.d/45-allow-xrdp.pkla << EOF
[Allow Restart XRDP]
Identity=unix-group:sudo
Action=org.freedesktop.systemd1.manage-units
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

# Enable xRDP service to start on boot
systemctl enable xrdp
check_status "xRDP enabled at startup"

# Start/restart xRDP service
systemctl restart xrdp
check_status "xRDP service started"

# Configure firewall to allow RDP connections (port 3389)
if command -v ufw &> /dev/null; then
    ufw allow 3389/tcp
    check_status "Firewall configured to allow RDP connections on port 3389"
fi

# Get the IP address for connecting
ip_address=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${BLUE}========================================================${NC}"
echo -e "${GREEN}Installation complete! Your system is now set up with:${NC}"
echo "1. Updated Ubuntu packages"
echo "2. Borg Backup (command-line) for backups"
if [[ "$install_vorta" == "y" || "$install_vorta" == "Y" ]]; then
    echo "   and Vorta (GUI) for visual backup management"
fi
echo "3. xRDP server for Windows Remote Desktop connections"
if [[ "$setup_new_user" == "y" || "$setup_new_user" == "Y" ]]; then
    echo "4. New user setup with sudo privileges"
fi
echo ""
echo -e "${YELLOW}To connect from Windows:${NC}"
echo "1. Open Remote Desktop Connection (mstsc.exe)"
echo "2. Enter the IP address of this machine: $ip_address"
echo "3. Log in with your Ubuntu username and password"
echo ""
if [[ "$install_vorta" == "y" || "$install_vorta" == "Y" ]]; then
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
