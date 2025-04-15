#!/bin/bash
# samba_setup.sh - Samba Server Setup functions
# This module handles Samba server installation and basic share configuration

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Main function for Samba setup
samba_setup() {
    print_section_header "Samba Server Setup"
    
    # Check if Samba is installed
    if ! is_package_installed "samba"; then
        if ask_yes_no "Samba is not installed. Would you like to install it?"; then
            apt update && apt install -y samba
            check_status "Installed Samba package" || return 1
        else
            echo -e "${YELLOW}Samba installation skipped.${NC}" | tee -a "$LOG_FILE"
            return 0
        fi
    else
        echo -e "${GREEN}Samba is already installed.${NC}" | tee -a "$LOG_FILE"
    fi

    # Configure a basic share
    if ask_yes_no "Would you like to configure a basic Samba share now?"; then
        configure_samba_share
        check_status "Configured Samba share" || return 1
    fi

    # Remind about user setup
    echo -e "\n${YELLOW}IMPORTANT:${NC} Remember to add Samba users using 'sudo smbpasswd -a <username>'." | tee -a "$LOG_FILE"
    echo -e "${YELLOW}The corresponding system user must exist first.${NC}" | tee -a "$LOG_FILE"

    return 0
}

# Function to configure a basic Samba share
configure_samba_share() {
    local share_name share_path comment writable guest_ok create_dir

    echo -e "\n${BLUE}--- Configure Samba Share ---${NC}" | tee -a "$LOG_FILE"

    # Get share details from user
    read -rp "Enter the name for the share (e.g., PublicShare): " share_name
    if [ -z "$share_name" ]; then
        echo -e "${RED}Share name cannot be empty.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    read -rp "Enter the full path for the share directory (e.g., /srv/samba/public): " share_path
    if [ -z "$share_path" ]; then
        echo -e "${RED}Share path cannot be empty.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    read -rp "Enter a comment for the share (optional): " comment

    writable=$(ask_yes_no "Should this share be writable?" && echo "yes" || echo "no")
    guest_ok=$(ask_yes_no "Allow guest (public) access (no password required)?" && echo "yes" || echo "no")

    # Create directory if needed
    if [ ! -d "$share_path" ]; then
        if ask_yes_no "Directory '$share_path' does not exist. Create it?"; then
            mkdir -p "$share_path"
            check_status "Created directory $share_path" || return 1
            # Set permissions (adjust as needed, this is a basic example)
            if [ "$guest_ok" == "yes" ] && [ "$writable" == "yes" ]; then
                chmod -R 0777 "$share_path"
                chown -R nobody:nogroup "$share_path"
                check_status "Set public permissions for $share_path" || return 1
            else
                 # More restrictive permissions if not public writable guest access
                 # You might want more granular control here depending on the use case
                chmod -R 0755 "$share_path" 
                # Consider setting ownership to a specific user/group if not guest access
                check_status "Set standard permissions for $share_path" || return 1
            fi
        else
            echo -e "${YELLOW}Share configuration skipped as directory does not exist.${NC}" | tee -a "$LOG_FILE"
            return 1
        fi
    fi

    # Backup existing smb.conf
    local smb_conf="/etc/samba/smb.conf"
    local backup_file="${smb_conf}.bak.$(date +%Y%m%d_%H%M%S)"
    if [ -f "$smb_conf" ]; then
        cp "$smb_conf" "$backup_file"
        check_status "Backed up $smb_conf to $backup_file" || return 1
    fi

    # Append share configuration
    echo -e "\nAppending configuration to $smb_conf..." | tee -a "$LOG_FILE"
    {
        echo ""
        echo "[$share_name]"
        echo "   path = $share_path"
        if [ -n "$comment" ]; then
            echo "   comment = $comment"
        fi
        echo "   writable = $writable"
        echo "   guest ok = $guest_ok"
        echo "   read only = $([ "$writable" == "yes" ] && echo "no" || echo "yes")"
        # Add browseable = yes if you want it to appear in network lists
        echo "   browseable = yes" 
        # Force user/group for guest access if enabled
        if [ "$guest_ok" == "yes" ]; then
             echo "   force user = nobody"
             echo "   force group = nogroup"
        fi

    } >> "$smb_conf" # Use tee -a for logging? Might be too verbose. Appending directly is fine.

    check_status "Appended share [$share_name] to $smb_conf" || return 1

    # Test smb.conf syntax
    echo "Testing Samba configuration..." | tee -a "$LOG_FILE"
    testparm -s
    if [ $? -ne 0 ]; then
        echo -e "${RED}Samba configuration test failed! Check $smb_conf.${NC}" | tee -a "$LOG_FILE"
        echo -e "${YELLOW}Restoring backup $backup_file...${NC}" | tee -a "$LOG_FILE"
        mv "$backup_file" "$smb_conf"
        return 1
    fi
    check_status "Samba configuration test successful"

    # Restart Samba service
    echo "Restarting Samba services..." | tee -a "$LOG_FILE"
    systemctl restart smbd nmbd
    check_status "Restarted smbd and nmbd services" || return 1

    echo -e "${GREEN}Samba share [$share_name] configured successfully.${NC}" | tee -a "$LOG_FILE"
    return 0
}

# Make the script executable (though it's sourced)
# chmod +x "${BASH_SOURCE[0]}" # Not strictly needed as it's sourced
