#!/bin/bash
# ssh_setup.sh - SSH server installation and configuration
# This module handles the setup and configuration of the SSH server

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Function to install and configure SSH server
setup_ssh_server() {
    print_section_header "Installing and Configuring SSH Server"

    # Install OpenSSH server if not already installed
    if ! is_package_installed "openssh-server"; then
        apt install openssh-server -y
        check_status "OpenSSH server installed" || return 1
    else
        echo -e "${GREEN}OpenSSH server is already installed.${NC}" | tee -a "$LOG_FILE"
    fi

    # Backup the SSH config file if backup doesn't exist
    backup_file "/etc/ssh/sshd_config"

    # Enhance SSH security configurations
    echo -e "${YELLOW}Configuring SSH for enhanced security...${NC}" | tee -a "$LOG_FILE"

    # Set configuration values idempotently
    set_config_value "/etc/ssh/sshd_config" "PasswordAuthentication" "yes"
    set_config_value "/etc/ssh/sshd_config" "PubkeyAuthentication" "yes"
    set_config_value "/etc/ssh/sshd_config" "PermitRootLogin" "prohibit-password"

    # Open SSH port in firewall if it's not already open
    if command -v ufw &> /dev/null; then
        if ! firewall_rule_exists "22/tcp"; then
            ufw allow ssh
            check_status "Firewall configured to allow SSH connections" || return 1
        else
            echo -e "${GREEN}Firewall already allows SSH connections.${NC}" | tee -a "$LOG_FILE"
        fi
    fi

    # Check if SSH service needs to be restarted due to config changes
    if systemctl is-active sshd &>/dev/null; then
        systemctl restart sshd
        check_status "SSH service restarted" || return 1
    else
        systemctl start sshd
        check_status "SSH service started" || return 1
    fi

    # Enable SSH service at boot
    systemctl enable sshd
    check_status "SSH service enabled at boot" || return 1
    
    echo -e "${GREEN}SSH server setup completed successfully.${NC}" | tee -a "$LOG_FILE"
    return 0
}

# Function to configure SSH server with advanced security options
configure_ssh_security() {
    print_section_header "Configuring Advanced SSH Security"
    
    # Backup the SSH config file if backup doesn't exist
    backup_file "/etc/ssh/sshd_config"
    
    # Configure additional security options
    echo -e "${YELLOW}Setting up additional SSH security measures...${NC}" | tee -a "$LOG_FILE"
    
    # Disable root login completely if requested
    if ask_yes_no "Do you want to completely disable root login via SSH?"; then
        set_config_value "/etc/ssh/sshd_config" "PermitRootLogin" "no"
    fi
    
    # Option to disable password authentication (force key-based only)
    if ask_yes_no "Do you want to disable password authentication (key-based auth only)?"; then
        set_config_value "/etc/ssh/sshd_config" "PasswordAuthentication" "no"
    fi
    
    # Change SSH port if requested
    if ask_yes_no "Do you want to change the default SSH port?"; then
        echo -n "Enter new SSH port number (1024-65535 recommended): "
        read -r new_port
        
        # Validate port number
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            set_config_value "/etc/ssh/sshd_config" "Port" "$new_port"
            
            # Update firewall rules for the new port
            if command -v ufw &> /dev/null; then
                ufw allow "$new_port/tcp"
                check_status "Firewall configured to allow SSH connections on port $new_port" || return 1
            fi
            
            echo -e "${YELLOW}SSH port changed to $new_port. Remember to connect using: ssh -p $new_port username@host${NC}" | tee -a "$LOG_FILE"
        else
            echo -e "${RED}Invalid port number. Keeping the default port.${NC}" | tee -a "$LOG_FILE"
        fi
    fi
    
    # Set idle timeout if requested
    if ask_yes_no "Do you want to set an idle timeout for SSH sessions?"; then
        set_config_value "/etc/ssh/sshd_config" "ClientAliveInterval" "300" "Send keepalive every 5 minutes"
        set_config_value "/etc/ssh/sshd_config" "ClientAliveCountMax" "3" "Disconnect after 3 failed keepalives (15 minutes total)"
    fi
    
    # Limit SSH access to specific users if requested
    if ask_yes_no "Do you want to limit SSH access to specific users?"; then
        echo "Enter usernames that should have SSH access (space-separated): "
        read -r allowed_users
        set_config_value "/etc/ssh/sshd_config" "AllowUsers" "$allowed_users"
    fi
    
    # Restart SSH service to apply changes
    systemctl restart sshd
    check_status "SSH service restarted with new security settings" || return 1
    
    echo -e "${GREEN}SSH security configuration completed successfully.${NC}" | tee -a "$LOG_FILE"
    return 0
}