#!/bin/bash
# remote_access.sh - Remote access setup (xRDP, VNC, etc.)
# This module handles installation and configuration of remote access tools

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Function to set up xRDP for Windows Remote Desktop connections
setup_xrdp() {
    print_section_header "Setting up Remote Desktop Server (xRDP)"
    
    # Install xRDP if not already installed
    if ! is_package_installed "xrdp"; then
        apt install xrdp -y
        check_status "xRDP installed" || return 1
    else
        echo -e "${GREEN}xRDP is already installed.${NC}" | tee -a "$LOG_FILE"
    fi

    # Install additional dependencies if not already installed
    if ! is_package_installed "xorgxrdp"; then
        apt install xorgxrdp -y
        check_status "xorgxrdp installed" || return 1
    else
        echo -e "${GREEN}xorgxrdp is already installed.${NC}" | tee -a "$LOG_FILE"
    fi

    # Configure xRDP for better compatibility
    print_section_header "Configuring xRDP for optimal performance"
    
    # Create backup of xrdp.ini if it doesn't exist
    backup_file "/etc/xrdp/xrdp.ini"

    # Update xRDP config for better performance (idempotently)
    set_config_value "/etc/xrdp/xrdp.ini" "max_bpp" "24"
    set_config_value "/etc/xrdp/xrdp.ini" "crypt_level" "low"

    # Fix known issues with desktop environments
    local real_user=$(get_real_user)
    if [ -n "$real_user" ]; then
        configure_xrdp_for_user "$real_user"
    fi

    # Create a polkit rule to allow anyone to restart xrdp if it doesn't exist
    local polkit_file="/etc/polkit-1/localauthority/50-local.d/45-allow-xrdp.pkla"
    if [ ! -f "$polkit_file" ]; then
        # Ensure directory exists
        mkdir -p "/etc/polkit-1/localauthority/50-local.d"

        cat > "$polkit_file" << EOF
[Allow Restart XRDP]
Identity=unix-group:sudo
Action=org.freedesktop.systemd1.manage-units
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF
        check_status "Created polkit rule for xRDP" || return 1
    else
        echo -e "${GREEN}Polkit rule for xRDP already exists.${NC}" | tee -a "$LOG_FILE"
    fi

    # Enable xRDP service to start on boot (idempotent)
    systemctl enable xrdp
    check_status "xRDP enabled at startup" || return 1

    # Restart xRDP service if it's running, otherwise start it
    if systemctl is-active xrdp &>/dev/null; then
        systemctl restart xrdp
        check_status "xRDP service restarted" || return 1
    else
        systemctl start xrdp
        check_status "xRDP service started" || return 1
    fi

    # Configure firewall to allow RDP connections (port 3389) if not already allowed
    if command -v ufw &> /dev/null; then
        if ! firewall_rule_exists "3389/tcp"; then
            ufw allow 3389/tcp
            check_status "Firewall configured to allow RDP connections on port 3389" || return 1
        else
            echo -e "${GREEN}Firewall already allows RDP connections.${NC}" | tee -a "$LOG_FILE"
        fi
    fi

    # Get the IP address for connecting
    local ip_address=$(hostname -I | awk '{print $1}')

    echo -e "${GREEN}xRDP has been successfully configured.${NC}" | tee -a "$LOG_FILE"
    echo -e "You can connect to this machine using Remote Desktop with:" | tee -a "$LOG_FILE"
    echo -e "IP Address: ${YELLOW}$ip_address${NC}" | tee -a "$LOG_FILE"
    echo -e "Use your Ubuntu username and password to log in." | tee -a "$LOG_FILE"

    return 0
}

# Function to configure xRDP for a specific user
configure_xrdp_for_user() {
    local username="$1"
    local user_home

    user_home=$(eval echo ~"$username")

    if [ ! -d "$user_home" ]; then
        echo -e "${RED}Home directory for user $username does not exist.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    echo -e "Configuring xRDP session for user ${YELLOW}$username${NC}" | tee -a "$LOG_FILE"

    # Check if .xsession already exists
    if [ -f "$user_home/.xsession" ]; then
        echo -e "${GREEN}.xsession file already exists for user $username. Checking configuration...${NC}" | tee -a "$LOG_FILE"
        # We could add more sophisticated checks here if needed
    else
        # Detect desktop environment and create appropriate .xsession file
        if [ -f /usr/bin/gnome-session ]; then
            echo "GNOME detected, configuring xRDP for GNOME..." | tee -a "$LOG_FILE"

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for GNOME
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg
exec gnome-session
EOF
        elif [ -f /usr/bin/xfce4-session ]; then
            echo "XFCE detected, configuring xRDP for XFCE..." | tee -a "$LOG_FILE"

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for XFCE
startxfce4
EOF
        elif [ -f /usr/bin/mate-session ]; then
            echo "MATE detected, configuring xRDP for MATE..." | tee -a "$LOG_FILE"

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for MATE
mate-session
EOF
        elif [ -f /usr/bin/cinnamon-session ]; then
            echo "Cinnamon detected, configuring xRDP for Cinnamon..." | tee -a "$LOG_FILE"

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for Cinnamon
cinnamon-session
EOF
        elif [ -f /usr/bin/startplasma-x11 ]; then
            echo "KDE Plasma detected, configuring xRDP for KDE..." | tee -a "$LOG_FILE"

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for KDE Plasma
export DESKTOP_SESSION=plasma
startplasma-x11
EOF
        elif [ -f /usr/bin/lxsession ]; then
            echo "LXDE detected, configuring xRDP for LXDE..." | tee -a "$LOG_FILE"

            cat > "$user_home/.xsession" << EOF
#!/bin/sh
# xRDP session startup for LXDE
lxsession
EOF
        else
            echo "No specific desktop environment detected, using default xRDP configuration." | tee -a "$LOG_FILE"
            return 0
        fi

        # Set correct permissions for .xsession file
        chmod +x "$user_home/.xsession"
        chown "$username":"$username" "$user_home/.xsession"
        echo "Session configuration file created at $user_home/.xsession" | tee -a "$LOG_FILE"
    fi

    return 0
}

# Function to set up VNC server (alternative to xRDP)
setup_vnc_server() {
    print_section_header "Setting up VNC Server"

    # Install TigerVNC or TightVNC
    if ! is_package_installed "tigervnc-standalone-server" && ! is_package_installed "tightvncserver"; then
        echo -e "${YELLOW}Installing TigerVNC server...${NC}" | tee -a "$LOG_FILE"
        apt install tigervnc-standalone-server -y
        check_status "TigerVNC server installed" || return 1
    else
        echo -e "${GREEN}VNC server is already installed.${NC}" | tee -a "$LOG_FILE"
    fi

    # Get the user for whom to set up VNC
    local user=$(get_real_user)
    if [ -z "$user" ] || [ "$user" = "root" ]; then
        echo -n "Enter the username for VNC server setup: "
        read -r user
        if ! id "$user" >/dev/null 2>&1; then
            echo -e "${RED}User '$user' does not exist.${NC}" | tee -a "$LOG_FILE"
            return 1
        fi
    fi

    local user_home=$(eval echo ~"$user")

    # Create VNC directory if it doesn't exist
    sudo -u "$user" mkdir -p "$user_home/.vnc"

    # Create VNC password
    echo -e "${YELLOW}Setting up VNC password for user $user${NC}" | tee -a "$LOG_FILE"
    echo -e "${YELLOW}Note: Password will be truncated to 8 characters for VNC${NC}" | tee -a "$LOG_FILE"
    
    # We use vncpasswd non-interactively
    echo -n "Enter VNC password: "
    read -s vnc_password
    echo
    
    # Write password to a temporary file and use it with vncpasswd
    echo "$vnc_password" > /tmp/vnc_passwd
    sudo -u "$user" bash -c "cat /tmp/vnc_passwd | vncpasswd -f > \"$user_home/.vnc/passwd\""
    rm /tmp/vnc_passwd
    
    # Set proper permissions on the password file
    chmod 600 "$user_home/.vnc/passwd"
    chown "$user":"$user" "$user_home/.vnc/passwd"
    
    # Create a xstartup file for VNC
    cat > "$user_home/.vnc/xstartup" << EOF
#!/bin/sh
# VNC startup script

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Detect desktop environment and start it
if [ -f /usr/bin/gnome-session ]; then
    exec gnome-session
elif [ -f /usr/bin/xfce4-session ]; then
    exec startxfce4
elif [ -f /usr/bin/mate-session ]; then
    exec mate-session
elif [ -f /usr/bin/cinnamon-session ]; then
    exec cinnamon-session
elif [ -f /usr/bin/startplasma-x11 ]; then
    export DESKTOP_SESSION=plasma
    exec startplasma-x11
elif [ -f /usr/bin/lxsession ]; then
    exec lxsession
else
    # Fallback to a basic window manager
    xsetroot -solid grey
    xterm -geometry 80x24+10+10 -ls -title "$VNCDESKTOP Desktop" &
    exec /usr/bin/fluxbox
fi
EOF

    # Set proper permissions
    chmod 755 "$user_home/.vnc/xstartup"
    chown "$user":"$user" "$user_home/.vnc/xstartup"

    # Create systemd service for VNC if it doesn't exist
    if [ ! -f "/etc/systemd/system/vncserver@.service" ]; then
        cat > "/etc/systemd/system/vncserver@.service" << EOF
[Unit]
Description=Remote desktop service (VNC)
After=network.target

[Service]
Type=forking
User=$user
Group=$user
WorkingDirectory=/home/$user

PIDFile=/home/$user/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver :%i -depth 24 -geometry 1920x1080
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        check_status "VNC systemd service created" || return 1
    fi

    # Enable and start the VNC service
    systemctl enable vncserver@1.service
    systemctl start vncserver@1.service
    check_status "VNC server enabled and started" || return 1
    
    # Configure firewall to allow VNC connections (port 5901) if not already allowed
    if command -v ufw &> /dev/null; then
        if ! firewall_rule_exists "5901/tcp"; then
            ufw allow 5901/tcp
            check_status "Firewall configured to allow VNC connections on port 5901" || return 1
        else
            echo -e "${GREEN}Firewall already allows VNC connections.${NC}" | tee -a "$LOG_FILE"
        fi
    fi

    # Get the IP address for connecting
    local ip_address=$(hostname -I | awk '{print $1}')

    echo -e "${GREEN}VNC server has been successfully configured.${NC}" | tee -a "$LOG_FILE"
    echo -e "You can connect to the VNC server with a VNC client using:" | tee -a "$LOG_FILE"
    echo -e "IP Address: ${YELLOW}$ip_address:1${NC}" | tee -a "$LOG_FILE"
    echo -e "Use the VNC password you just created to log in." | tee -a "$LOG_FILE"
    
    return 0
}