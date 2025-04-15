# Function to manage Samba users
manage_samba_users() {
    print_section_header "Managing Samba Users"
    
    # Check if pdbedit is available
    if ! command_exists pdbedit; then
        echo -e "${RED}Error: pdbedit command not found. Please install samba-common-bin package.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    local choice
    while true; do
        echo -e "\n${BLUE}=== Samba User Management ===${NC}" | tee -a "$LOG_FILE"
        echo "1. List Samba users"
        echo "2. Add a new Samba user"
        echo "3. Change a Samba user's password"
        echo "4. Delete a Samba user"
        echo "5. Back to Samba menu"
        
        read -rp "Enter your choice: " choice
        
        case $choice in
            1)
                echo -e "${YELLOW}Current Samba users:${NC}" | tee -a "$LOG_FILE"
                if pdbedit -L 2>/dev/null | grep -q .; then
                    pdbedit -L -v 2>/dev/null | grep -E "Unix username|Account Flags" || echo "Error retrieving user information."
                else
                    echo -e "${YELLOW}No Samba users found.${NC}" | tee -a "$LOG_FILE"
                fi
                ;;
            2)
                add_samba_user
                ;;
            3)
                change_samba_password
                ;;
            4)
                delete_samba_user
                ;;
            5)
                return 0
                ;;
            *)
                echo -e "${RED}Invalid choice.${NC}" | tee -a "$LOG_FILE"
                ;;
        esac
    done
}

# Function to add a Samba user
add_samba_user() {
    local username
    
    # Get the list of system users
    echo -e "${YELLOW}System users:${NC}" | tee -a "$LOG_FILE"
    getent passwd | grep -E '/home/[^:]+:/bin/(ba)?sh' | cut -d: -f1 | sort
    
    echo -n "Enter username to add to Samba (must be an existing system user): "
    read -r username
    
    # Check if the user exists on the system
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}Error: User '$username' does not exist on the system.${NC}" | tee -a "$LOG_FILE"
        echo -e "${YELLOW}You must create the system user first using 'sudo adduser $username'.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Check if the user already exists in Samba
    if pdbedit -L 2>/dev/null | grep -q "^$username:"; then
        echo -e "${YELLOW}User '$username' already exists in Samba.${NC}" | tee -a "$LOG_FILE"
        if ask_yes_no "Would you like to reset the password?"; then
            if ! smbpasswd -a "$username"; then
                echo -e "${RED}Failed to reset password for $username. Check permissions.${NC}" | tee -a "$LOG_FILE"
                return 1
            fi
            check_status "Reset Samba password for user $username" || return 1
        fi
        return 0
    fi
    
    # Add the user to Samba
    echo -e "${YELLOW}Adding user '$username' to Samba. Please enter the Samba password:${NC}" | tee -a "$LOG_FILE"
    if ! smbpasswd -a "$username"; then
        echo -e "${RED}Failed to add user $username to Samba. Check permissions.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    if pdbedit -L 2>/dev/null | grep -q "^$username:"; then
        echo -e "${GREEN}User '$username' has been added to Samba successfully.${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}Failed to add user '$username' to Samba.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    return 0
}

# Function to change a Samba user's password
change_samba_password() {
    local username
    
    # List Samba users
    echo -e "${YELLOW}Current Samba users:${NC}" | tee -a "$LOG_FILE"
    pdbedit -L 2>/dev/null | cut -d: -f1 || echo "No users found or error retrieving users."
    
    echo -n "Enter username to change password: "
    read -r username
    
    # Check if the user exists in Samba
    if ! pdbedit -L 2>/dev/null | grep -q "^$username:"; then
        echo -e "${RED}Error: User '$username' does not exist in Samba.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Change the password
    echo -e "${YELLOW}Changing Samba password for user '$username'. Please enter the new password:${NC}" | tee -a "$LOG_FILE"
    if ! smbpasswd "$username"; then
        echo -e "${RED}Failed to change password for $username. Check permissions.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    echo -e "${GREEN}Password for user '$username' has been changed successfully.${NC}" | tee -a "$LOG_FILE"
    return 0
}

# Function to delete a Samba user
delete_samba_user() {
    local username
    
    # List Samba users
    echo -e "${YELLOW}Current Samba users:${NC}" | tee -a "$LOG_FILE"
    pdbedit -L 2>/dev/null | cut -d: -f1 || echo "No users found or error retrieving users."
    
    echo -n "Enter username to delete from Samba: "
    read -r username
    
    # Check if the user exists in Samba
    if ! pdbedit -L 2>/dev/null | grep -q "^$username:"; then
        echo -e "${RED}Error: User '$username' does not exist in Samba.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Confirm deletion
    if ask_yes_no "Are you sure you want to delete Samba user '$username'?"; then
        # Delete the user from Samba
        if ! pdbedit -x -u "$username"; then
            echo -e "${RED}Failed to delete user $username from Samba. Check permissions.${NC}" | tee -a "$LOG_FILE"
            return 1
        fi
        
        echo -e "${GREEN}User '$username' has been deleted from Samba successfully.${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}User deletion canceled.${NC}" | tee -a "$LOG_FILE"
    fi
    
    return 0
}

# Function to configure Samba security settings
configure_samba_security() {
    print_section_header "Configuring Samba Security"
    
    local smb_conf="/etc/samba/smb.conf"
    local backup_file="${smb_conf}.bak.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$smb_conf" ]; then
        cp "$smb_conf" "$backup_file"
        echo "Created backup at $backup_file" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}Error: $smb_conf not found. Is Samba installed correctly?${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Security options
    echo -e "\n${BLUE}=== Samba Security Options ===${NC}" | tee -a "$LOG_FILE"
    
    # Configure user account lockout
    if ask_yes_no "Would you like to enable account lockout after failed login attempts?"; then
        local max_attempts
        echo -n "Enter maximum failed login attempts before lockout (recommended: 5): "
        read -r max_attempts
        
        if ! [[ "$max_attempts" =~ ^[0-9]+$ ]]; then
            max_attempts=5
            echo -e "${YELLOW}Invalid input. Using default value of 5.${NC}" | tee -a "$LOG_FILE"
        fi
        
        # Add or update bad password settings
        if grep -q "bad password" "$smb_conf"; then
            sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*bad password attempts[[:space:]]*=\).*/\1 $max_attempts/" "$smb_conf"
        else
            sed -i "/\[global\]/a\\tbad password attempts = $max_attempts" "$smb_conf"
        fi
        
        # Set lockout duration
        local lockout_time
        echo -n "Enter account lockout time in minutes (recommended: 30): "
        read -r lockout_time
        
        if ! [[ "$lockout_time" =~ ^[0-9]+$ ]]; then
            lockout_time=30
            echo -e "${YELLOW}Invalid input. Using default value of 30 minutes.${NC}" | tee -a "$LOG_FILE"
        fi
        
        # Convert minutes to seconds for Samba
        local lockout_seconds=$((lockout_time * 60))
        
        if grep -q "lockout time" "$smb_conf"; then
            sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*lockout time[[:space:]]*=\).*/\1 $lockout_seconds/" "$smb_conf"
        else
            sed -i "/\[global\]/a\\tlockout time = $lockout_seconds" "$smb_conf"
        fi
        
        check_status "Configured account lockout settings" || return 1
    fi
    
    # Password complexity requirements
    if ask_yes_no "Would you like to enforce password complexity requirements?"; then
        if grep -q "check password script" "$smb_conf"; then
            sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*check password script[[:space:]]*=\).*/\1 \/usr\/local\/bin\/check_password.sh/" "$smb_conf"
        else
            sed -i "/\[global\]/a\\tcheck password script = /usr/local/bin/check_password.sh" "$smb_conf"
        fi
        
        # Create password script
        cat > /usr/local/bin/check_password.sh << 'EOF'
#!/bin/bash
# Simple password checking script for Samba
# Return 0 if password is acceptable, non-zero otherwise

PASSWORD="$1"
USERNAME="$2"

# Check password length (minimum 8 characters)
if [ ${#PASSWORD} -lt 8 ]; then
    echo "Password is too short (minimum 8 characters)"
    exit 1
fi

# Check if password contains at least one uppercase letter
if ! echo "$PASSWORD" | grep -q "[A-Z]"; then
    echo "Password must contain at least one uppercase letter"
    exit 1
fi

# Check if password contains at least one lowercase letter
if ! echo "$PASSWORD" | grep -q "[a-z]"; then
    echo "Password must contain at least one lowercase letter"
    exit 1
fi

# Check if password contains at least one digit
if ! echo "$PASSWORD" | grep -q "[0-9]"; then
    echo "Password must contain at least one digit"
    exit 1
fi

# Check if password contains at least one special character
if ! echo "$PASSWORD" | grep -q "[^A-Za-z0-9]"; then
    echo "Password must contain at least one special character"
    exit 1
fi

# Check if password contains the username
if echo "$PASSWORD" | grep -qi "$USERNAME"; then
    echo "Password must not contain the username"
    exit 1
fi

# All checks passed
exit 0
EOF

        if ! chmod +x /usr/local/bin/check_password.sh; then
            echo -e "${RED}Failed to set executable permissions on password script.${NC}" | tee -a "$LOG_FILE"
            return 1
        fi
        check_status "Created password complexity script" || return 1
        
        # Enable password checking
        if grep -q "unix password sync" "$smb_conf"; then
            sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*unix password sync[[:space:]]*=\).*/\1 yes/" "$smb_conf"
        else
            sed -i "/\[global\]/a\\tunix password sync = yes" "$smb_conf"
        fi
        
        check_status "Enabled password complexity checking" || return 1
    fi
    
    # Configure Samba minimum protocol version for security
    echo -e "${YELLOW}Select minimum allowed SMB protocol version:${NC}" | tee -a "$LOG_FILE"
    echo "1. SMB1 (Legacy, least secure)"
    echo "2. SMB2 (Better security)"
    echo "3. SMB3 (Most secure, recommended)"
    
    local protocol_choice
    read -rp "Enter your choice (default: 3): " protocol_choice
    
    local min_protocol
    case $protocol_choice in
        1) min_protocol="NT1" ;;
        2) min_protocol="SMB2" ;;
        *) min_protocol="SMB3" ;;
    esac
    
    if grep -q "server min protocol" "$smb_conf"; then
        sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*server min protocol[[:space:]]*=\).*/\1 $min_protocol/" "$smb_conf"
    else
        sed -i "/\[global\]/a\\tserver min protocol = $min_protocol" "$smb_conf"
    fi
    
    check_status "Set minimum protocol version to $min_protocol" || return 1
    
    # Configure hosts allow/deny
    if ask_yes_no "Would you like to restrict access by IP address?"; then
        echo -n "Enter allowed IP addresses/networks (space-separated, e.g., 192.168.1. 10.0.0.): "
        read -r allowed_ips
        
        if [ -n "$allowed_ips" ]; then
            # Format the list properly
            allowed_ips=$(echo "$allowed_ips" | tr ' ' ',')
            
            if grep -q "hosts allow" "$smb_conf"; then
                sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*hosts allow[[:space:]]*=\).*/\1 $allowed_ips/" "$smb_conf"
            else
                sed -i "/\[global\]/a\\thosts allow = $allowed_ips" "$smb_conf"
            fi
            
            # Deny all other hosts
            if grep -q "hosts deny" "$smb_conf"; then
                sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*hosts deny[[:space:]]*=\).*/\1 ALL/" "$smb_conf"
            else
                sed -i "/\[global\]/a\\thosts deny = ALL" "$smb_conf"
            fi
            
            check_status "Configured IP address restrictions" || return 1
        fi
    fi
    
    # Configure SMB signing
    if ask_yes_no "Would you like to enable SMB signing for additional security?"; then
        # Add or update server signing options
        if grep -q "server signing" "$smb_conf"; then
            sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*server signing[[:space:]]*=\).*/\1 mandatory/" "$smb_conf"
        else
            sed -i "/\[global\]/a\\tserver signing = mandatory" "$smb_conf"
        fi
        
        check_status "Enabled mandatory SMB signing" || return 1
    fi
    
    # Test configuration before restarting
    if command_exists testparm; then
        echo -e "${YELLOW}Testing Samba configuration...${NC}" | tee -a "$LOG_FILE"
        if ! testparm -s >/dev/null 2>&1; then
            echo -e "${RED}Samba configuration test failed! Reverting to backup...${NC}" | tee -a "$LOG_FILE"
            cp "$backup_file" "$smb_conf"
            return 1
        fi
    else
        echo -e "${YELLOW}Warning: testparm not found, skipping configuration test.${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Restart Samba service
    echo -e "${YELLOW}Restarting Samba services to apply security settings...${NC}" | tee -a "$LOG_FILE"
    if ! systemctl restart smbd nmbd; then
        echo -e "${RED}Failed to restart Samba services. Reverting to backup...${NC}" | tee -a "$LOG_FILE"
        cp "$backup_file" "$smb_conf"
        return 1
    fi
    
    check_status "Applied security settings and restarted Samba services" || return 1
    
    echo -e "${GREEN}Samba security settings configured successfully.${NC}" | tee -a "$LOG_FILE"
    return 0
}

# Function to view Samba status
view_samba_status() {
    print_section_header "Samba Status Information"
    
    # Check if Samba services are running
    echo -e "${YELLOW}Samba Service Status:${NC}" | tee -a "$LOG_FILE"
    systemctl status smbd nmbd --no-pager || echo "Could not get service status"
    
    # List shares
    echo -e "\n${YELLOW}Available Shares:${NC}" | tee -a "$LOG_FILE"
    if command_exists smbclient; then
        smbclient -L localhost -N 2>/dev/null | grep -v "failed" || echo "Could not list shares"
    else
        echo "smbclient not found. Cannot list shares."
    fi
    
    # Show connected users
    echo -e "\n${YELLOW}Connected Users:${NC}" | tee -a "$LOG_FILE"
    if command_exists smbstatus; then
        smbstatus --brief 2>/dev/null || echo "No connected users or error getting status"
    else
        echo "smbstatus not found. Cannot show connected users."
    fi
    
    # Check configuration
    echo -e "\n${YELLOW}Configuration Check:${NC}" | tee -a "$LOG_FILE"
    if command_exists testparm; then
        testparm -s 2>/dev/null || echo "Error in configuration"
    else
        echo "testparm not found. Cannot check configuration."
    fi
    
    # Network configuration
    echo -e "\n${YELLOW}Network Information:${NC}" | tee -a "$LOG_FILE"
    ip -brief address 2>/dev/null | grep -v "lo" || echo "Could not get network information"
    
    # Firewall status
    echo -e "\n${YELLOW}Firewall Status:${NC}" | tee -a "$LOG_FILE"
    if command_exists ufw; then
        ufw status | grep -E "Samba|137|138|139|445" || echo "No Samba-related firewall rules found"
    else
        echo "UFW firewall not installed."
    fi
    
    echo -e "\n${GREEN}Press Enter to continue...${NC}"
    read -r
    
    return 0
}

# Function to manage existing Samba shares
manage_samba_shares() {
    print_section_header "Managing Existing Samba Shares"
    
    local smb_conf="/etc/samba/smb.conf"
    local share_choice
    
    # Get list of existing shares
    local shares=($(grep -E "^\[.*\]$" "$smb_conf" 2>/dev/null | grep -v "\[global\]" | grep -v "\[printers\]" | grep -v "\[print\$\]" | tr -d '[]'))
    
    if [ ${#shares[@]} -eq 0 ]; then
        echo -e "${YELLOW}No custom shares found. Create a new share first.${NC}" | tee -a "$LOG_FILE"
        return 0
    fi
    
    echo -e "${YELLOW}Select a share to manage:${NC}" | tee -a "$LOG_FILE"
    for i in "${!shares[@]}"; do
        echo "$((i+1)). ${shares[$i]}"
    done
    echo "$((${#shares[@]}+1)). Back to Samba menu"
    
    read -rp "Enter your choice: " share_choice
    
    # Validate input is numeric
    if ! [[ "$share_choice" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid choice. Please enter a number.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    if [ "$share_choice" -eq "$((${#shares[@]}+1))" ]; then
        return 0
    elif [ "$share_choice" -ge 1 ] && [ "$share_choice" -le "${#shares[@]}" ]; then
        local selected_share=${shares[$((share_choice-1))]}
        manage_specific_share "$selected_share"
    else
        echo -e "${RED}Invalid choice.${NC}" | tee -a "$LOG_FILE"
    fi
    
    return 0
}

# Function to manage a specific share
manage_specific_share() {
    local share_name="$1"
    local smb_conf="/etc/samba/smb.conf"
    local option_choice
    
    while true; do
        echo -e "\n${BLUE}=== Managing Share [$share_name] ===${NC}" | tee -a "$LOG_FILE"
        echo "1. View share details"
        echo "2. Modify share path"
        echo "3. Toggle guest access"
        echo "4. Toggle write access"
        echo "5. Toggle browseable status"
        echo "6. Delete share"
        echo "7. Back to shares list"
        
        read -rp "Enter your choice: " option_choice
        
        case $option_choice in
            1)
                echo -e "${YELLOW}Details for share [$share_name]:${NC}" | tee -a "$LOG_FILE"
                sed -n "/\[$share_name\]/,/^\[/p" "$smb_conf" 2>/dev/null | sed '$d' | grep -v "^\[$share_name\]$"
                read -rp "Press Enter to continue..."
                ;;
            2)
                local new_path
                read -rp "Enter new path for this share: " new_path
                if [ -n "$new_path" ]; then
                    # Create directory if it doesn't exist
                    if [ ! -d "$new_path" ]; then
                        if ask_yes_no "Directory '$new_path' does not exist. Create it?"; then
                            if ! mkdir -p "$new_path"; then
                                echo -e "${RED}Failed to create directory $new_path. Check permissions.${NC}" | tee -a "$LOG_FILE"
                                continue
                            fi
                            check_status "Created directory $new_path" || continue
                        else
                            echo -e "${YELLOW}Path change canceled.${NC}" | tee -a "$LOG_FILE"
                            continue
                        fi
                    fi
                    
                    # Backup config with timestamp
                    local backup_file="${smb_conf}.bak.$(date +%Y%m%d_%H%M%S)"
                    cp "$smb_conf" "$backup_file"
                    echo "Created backup at $backup_file" | tee -a "$LOG_FILE"
                    
                    # Update path in smb.conf
                    sed -i "/\[$share_name\]/,/^\[/ s|^\([[:space:]]*path[[:space:]]*=[[:space:]]*\).*$|\1$new_path|" "$smb_conf"
                    check_status "Updated path for share [$share_name]" || continue
                    
                    # Test configuration before restarting
                    if command_exists testparm; then
                        if ! testparm -s >/dev/null 2>&1; then
                            echo -e "${RED}Samba configuration test failed! Reverting changes...${NC}" | tee -a "$LOG_FILE"
                            cp "$backup_file" "$smb_conf"
                            continue
                        fi
                    fi
                    
                    # Restart Samba
                    if ! systemctl restart smbd nmbd; then
                        echo -e "${RED}Failed to restart Samba services. Reverting to backup...${NC}" | tee -a "$LOG_FILE"
                        cp "$backup_file" "$smb_conf"
                        continue
                    fi
                    
                    check_status "Applied path change and restarted Samba services" || continue
                }
                ;;
            3)
                # Toggle guest access
                local current_guest=$(sed -n "/\[$share_name\]/,/^\[/ s/^[[:space:]]*guest ok[[:space:]]*=[[:space:]]*//p" "$smb_conf" 2>/dev/null | head -1 | tr -d '[:space:]')
                
                local new_guest
                if [ "$current_guest" == "yes" ]; then
                    new_guest="no"
                else
                    new_guest="yes"
                fi
                
                # Backup config with timestamp
                local backup_file="${smb_conf}.bak.$(date +%Y%m%d_%H%M%S)"
                cp "$smb_conf" "$backup_file"
                echo "Created backup at $backup_file" | tee -a "$LOG_FILE"
                
                if grep -q "guest ok" <(sed -n "/\[$share_name\]/,/^\[/p" "$smb_conf" 2>/dev/null); then
                    sed -i "/\[$share_name\]/,/^\[/ s/^\([[:space:]]*guest ok[[:space:]]*=[[:space:]]*\).*$/\1$new_guest/" "$smb_conf"
                else
                    sed -i "/\[$share_name\]/a\\   guest ok = $new_guest" "$smb_conf"
                fi
                
                check_status "Updated guest access for share [$share_name] to $new_guest" || continue
                
                # Test configuration before restarting
                if command_exists testparm; then
                    if ! testparm -s >/dev/null 2>&1; then
                        echo -e "${RED}Samba configuration test failed! Reverting changes...${NC}" | tee -a "$LOG_FILE"
                        cp "$backup_file" "$smb_conf"
                        continue
                    fi
                fi
                
                # Restart Samba
                if ! systemctl restart smbd nmbd; then
                    echo -e "${RED}Failed to restart Samba services. Reverting to backup...${NC}" | tee -a "$LOG_FILE"
                    cp "$backup_file" "$smb_conf"
                    continue
                fi
                
                check_status "Applied guest access change and restarted Samba services" || continue
                ;;
            4)
                # Toggle write access
                local current_readonly=$(sed -n "/\[$share_name\]/,/^\[/ s/^[[:space:]]*read only[[:space:]]*=[[:space:]]*//p" "$smb_conf" 2>/dev/null | head -1 | tr -d '[:space:]')
                
                local new_readonly new_writable
                if [ "$current_readonly" == "yes" ]; then
                    new_readonly="no"
                    new_writable="yes"
                else
                    new_readonly="yes"
                    new_writable="no"
                fi
                
                # Backup config with timestamp
                local backup_file="${smb_conf}.bak.$(date +%Y%m%d_%H%M%S)"
                cp "$smb_conf" "$backup_file"
                echo "Created backup at $backup_file" | tee -a "$LOG_FILE"
                
                if grep -q "read only" <(sed -n "/\[$share_name\]/,/^\[/p" "$smb_conf" 2>/dev/null); then
                    sed -i "/\[$share_name\]/,/^\[/ s/^\([[:space:]]*read only[[:space:]]*=[[:space:]]*\).*$/\1$new_readonly/" "$smb_conf"
                else
                    sed -i "/\[$share_name\]/a\\   read only = $new_readonly" "$smb_conf"
                fi
                
                if grep -q "writable" <(sed -n "/\[$share_name\]/,/^\[/p" "$smb_conf" 2>/dev/null); then
                    sed -i "/\[$share_name\]/,/^\[/ s/^\([[:space:]]*writable[[:space:]]*=[[:space:]]*\).*$/\1$new_writable/" "$smb_conf"
                else
                    sed -i "/\[$share_name\]/a\\   writable = $new_writable" "$smb_conf"
                fi
                
                check_status "Updated write access for share [$share_name] to $new_writable" || continue
                
                # Test configuration before restarting
                if command_exists testparm; then
                    if ! testparm -s >/dev/null 2>&1; then
                        echo -e "${RED}Samba configuration test failed! Reverting changes...${NC}" | tee -a "$LOG_FILE"
                        cp "$backup_file" "$smb_conf"
                        continue
                    fi
                fi
                
                # Restart Samba
                if ! systemctl restart smbd nmbd; then
                    echo -e "${RED}Failed to restart Samba services. Reverting to backup...${NC}" | tee -a "$LOG_FILE"
                    cp "$backup_file" "$smb_conf"
                    continue
                fi
                
                check_status "Applied write access change and restarted Samba services" || continue
                ;;
            5)
                # Toggle browseable status
                local current_browseable=$(sed -n "/\[$share_name\]/,/^\[/ s/^[[:space:]]*browseable[[:space:]]*=[[:space:]]*//p" "$smb_conf" 2>/dev/null | head -1 | tr -d '[:space:]')
                
                local new_browseable
                if [ "$current_browseable" == "yes" ]; then
                    new_browseable="no"
                else
                    new_browseable="yes"
                fi
                
                # Backup config with timestamp
                local backup_file="${smb_conf}.bak.$(date +%Y%m%d_%H%M%S)"
                cp "$smb_conf" "$backup_file"
                echo "Created backup at $backup_file" | tee -a "$LOG_FILE"
                
                if grep -q "browseable" <(sed -n "/\[$share_name\]/,/^\[/p" "$smb_conf" 2>/dev/null); then
                    sed -i "/\[$share_name\]/,/^\[/ s/^\([[:space:]]*browseable[[:space:]]*=[[:space:]]*\).*$/\1$new_browseable/" "$smb_conf"
                else
                    sed -i "/\[$share_name\]/a\\   browseable = $new_browseable" "$smb_conf"
                fi
                
                check_status "Updated browseable status for share [$share_name] to $new_browseable" || continue
                
                # Test configuration before restarting
                if command_exists testparm; then
                    if ! testparm -s >/dev/null 2>&1; then
                        echo -e "${RED}Samba configuration test failed! Reverting changes...${NC}" | tee -a "$LOG_FILE"
                        cp "$backup_file" "$smb_conf"
                        continue
                    fi
                fi
                
                # Restart Samba
                if ! systemctl restart smbd nmbd; then
                    echo -e "${RED}Failed to restart Samba services. Reverting to backup...${NC}" | tee -a "$LOG_FILE"
                    cp "$backup_file" "$smb_conf"
                    continue
                fi
                
                check_status "Applied browseable status change and restarted Samba services" || continue
                ;;
            6)
                # Delete share
                if ask_yes_no "Are you sure you want to delete share [$share_name]? This cannot be undone."; then
                    # Backup config with timestamp
                    local backup_file="${smb_conf}.bak.$(date +%Y%m%d_%H%M%S)"
                    cp "$smb_conf" "$backup_file"
                    echo "Created backup at $backup_file" | tee -a "$LOG_FILE"
                    
                    # Get share path before deletion (to potentially ask about directory removal)
                    local share_path=$(sed -n "/\[$share_name\]/,/^\[/ s/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p" "$smb_conf" 2>/dev/null | head -1 | tr -d '[:space:]')
                    
                    # Use a safer approach to delete share section from smb.conf
                    # Create a temporary file
                    local temp_file=$(mktemp)
                    
                    # Flag to track when we're in the section to delete
                    local in_section=0
                    
                    # Process file line by line
                    while IFS= read -r line; do
                        # Check if we've found the section start
                        if [[ "$line" == "[$share_name]" ]]; then
                            in_section=1
                            continue
                        fi
                        
                        # Check if we've found the next section start (end of our section)
                        if [[ "$line" =~ ^\[.*\]$ ]] && [ $in_section -eq 1 ]; then
                            in_section=0
                        fi
                        
                        # If we're not in the section, output the line
                        if [ $in_section -eq 0 ]; then
                            echo "$line" >> "$temp_file"
                        fi
                    done < "$smb_conf"
                    
                    # Replace original file with our filtered version
                    mv "$temp_file" "$smb_conf"
                    
                    check_status "Deleted share [$share_name] from configuration" || continue
                    
                    # Test configuration before restarting
                    if command_exists testparm; then
                        if ! testparm -s >/dev/null 2>&1; then
                            echo -e "${RED}Samba configuration test failed! Reverting changes...${NC}" | tee -a "$LOG_FILE"
                            cp "$backup_file" "$smb_conf"
                            continue
                        fi
                    fi
                    
                    # Restart Samba
                    if ! systemctl restart smbd nmbd; then
                        echo -e "${RED}Failed to restart Samba services. Reverting to backup...${NC}" | tee -a "$LOG_FILE"
                        cp "$backup_file" "$smb_conf"
                        continue
                    fi
                    
                    check_status "Applied share deletion and restarted Samba services" || continue
                    
                    # Ask about removing the shared directory
                    if [ -n "$share_path" ] && [ -d "$share_path" ]; then
                        if ask_yes_no "Would you also like to remove the shared directory ($share_path)?"; then
                            if ! rm -rf "$share_path"; then
                                echo -e "${YELLOW}Warning: Could not remove directory. Check permissions.${NC}" | tee -a "$LOG_FILE"
                            else
                                check_status "Removed directory $share_path" || echo -e "${YELLOW}Warning: Could not remove directory.${NC}" | tee -a "$LOG_FILE"
                            fi
                        fi
                    fi
                    
                    echo -e "${GREEN}Share [$share_name] has been deleted.${NC}" | tee -a "$LOG_FILE"
                    return 0
                fi
                ;;
            7)
                return 0
                ;;
            *)
                echo -e "${RED}Invalid choice.${NC}" | tee -a "$LOG_FILE"
                ;;
        esac
    done
}#!/bin/bash
# samba_setup.sh - Samba Server Setup functions
# This module handles Samba server installation and comprehensive share configuration

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Main function for Samba setup
samba_setup() {
    print_section_header "Samba Server Setup"
    
    # Install Samba if not already installed
    install_samba_packages
    
    # Display main Samba configuration menu
    samba_main_menu
    
    return 0
}

# Function to install Samba packages
install_samba_packages() {
    # Check if Samba is installed
    if ! is_package_installed "samba"; then
        if ask_yes_no "Samba is not installed. Would you like to install it?"; then
            echo -e "${YELLOW}Installing Samba and required packages...${NC}" | tee -a "$LOG_FILE"
            apt update && apt install -y samba samba-common samba-common-bin
            check_status "Installed Samba packages" || return 1
            
            # Check if Samba has been installed successfully
            if ! is_package_installed "samba"; then
                echo -e "${RED}Failed to install Samba. Please check your internet connection and try again.${NC}" | tee -a "$LOG_FILE"
                return 1
            fi
            
            echo -e "${GREEN}Samba has been installed successfully.${NC}" | tee -a "$LOG_FILE"
        else
            echo -e "${YELLOW}Samba installation skipped.${NC}" | tee -a "$LOG_FILE"
            return 0
        fi
    else
        echo -e "${GREEN}Samba is already installed.${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Check for required Samba utilities
    local missing_utils=()
    for util in pdbedit testparm smbclient smbstatus; do
        if ! command_exists "$util"; then
            missing_utils+=("$util")
        fi
    done
    
    if [ ${#missing_utils[@]} -gt 0 ]; then
        echo -e "${YELLOW}Warning: The following Samba utilities are missing: ${missing_utils[*]}${NC}" | tee -a "$LOG_FILE"
        echo -e "${YELLOW}Some functionality may be limited.${NC}" | tee -a "$LOG_FILE"
        
        # Try to install any missing utilities
        if ask_yes_no "Would you like to install missing Samba utilities?"; then
            apt update && apt install -y samba-common-bin
            check_status "Installed Samba utilities" || echo -e "${YELLOW}Some utilities might still be missing.${NC}" | tee -a "$LOG_FILE"
        fi
    fi
    
    return 0
}

# Main Samba menu
samba_main_menu() {
    local choice
    while true; do
        echo -e "\n${BLUE}=== Samba Configuration Menu ===${NC}" | tee -a "$LOG_FILE"
        echo "1. Configure Samba Global Settings"
        echo "2. Create New Share"
        echo "3. Manage Existing Shares"
        echo "4. Manage Samba Users"
        echo "5. Configure Samba Security"
        echo "6. View Samba Status"
        echo "7. Back to Main Menu"
        
        echo -n "Enter your choice (1-7): "
        read -r choice
        
        case $choice in
            1) configure_samba_global ;;
            2) create_samba_share ;;
            3) manage_samba_shares ;;
            4) manage_samba_users ;;
            5) configure_samba_security ;;
            6) view_samba_status ;;
            7) return 0 ;;
            *) echo -e "${RED}Invalid choice. Please enter a number between 1 and 7.${NC}" | tee -a "$LOG_FILE" ;;
        esac
    done
}

# Function to configure global Samba settings
configure_samba_global() {
    print_section_header "Configuring Samba Global Settings"
    
    # Check if testparm exists before using it
    if ! command_exists testparm; then
        echo -e "${RED}Error: testparm command not found. Please install samba-common-bin package.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Backup smb.conf with timestamp
    local smb_conf="/etc/samba/smb.conf"
    local backup_file="${smb_conf}.bak.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$smb_conf" ]; then
        cp "$smb_conf" "$backup_file"
        echo "Created backup at $backup_file" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}Error: $smb_conf not found. Is Samba installed correctly?${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Get current workgroup and server string if they exist
    local current_workgroup=$(grep -E "^[[:space:]]*workgroup[[:space:]]*=" "$smb_conf" 2>/dev/null | sed 's/^[[:space:]]*workgroup[[:space:]]*=[[:space:]]*\(.*\)/\1/' | tr -d '[:space:]' | head -1)
    local current_server_string=$(grep -E "^[[:space:]]*server string[[:space:]]*=" "$smb_conf" 2>/dev/null | sed 's/^[[:space:]]*server string[[:space:]]*=[[:space:]]*\(.*\)/\1/' | tr -d '[:space:]' | head -1)
    
    [ -z "$current_workgroup" ] && current_workgroup="WORKGROUP"
    [ -z "$current_server_string" ] && current_server_string="Samba Server"
    
    # Get new settings
    echo -e "${YELLOW}Current workgroup is: ${GREEN}$current_workgroup${NC}" | tee -a "$LOG_FILE"
    echo -n "Enter new workgroup name (or press Enter to keep current): "
    read -r new_workgroup
    if [ -z "$new_workgroup" ]; then
        new_workgroup="$current_workgroup"
    fi
    
    echo -e "${YELLOW}Current server description is: ${GREEN}$current_server_string${NC}" | tee -a "$LOG_FILE"
    echo -n "Enter new server description (or press Enter to keep current): "
    read -r new_server_string
    if [ -z "$new_server_string" ]; then
        new_server_string="$current_server_string"
    fi
    
    # Configure NetBIOS name
    local hostname=$(hostname)
    echo -e "${YELLOW}Current hostname is: ${GREEN}$hostname${NC}" | tee -a "$LOG_FILE"
    echo -n "Enter NetBIOS name for the server (or press Enter to use hostname): "
    read -r netbios_name
    if [ -z "$netbios_name" ]; then
        netbios_name="$hostname"
    fi
    
    # Configure logging
    local log_level
    echo -e "${YELLOW}Select log level:${NC}" | tee -a "$LOG_FILE"
    echo "1. Minimal logging (0)"
    echo "2. Normal logging (1)"
    echo "3. Verbose logging (2)"
    echo "4. Debug level logging (3)"
    
    echo -n "Enter your choice (1-4): "
    read -r log_choice
    
    case $log_choice in
        1) log_level="0" ;;
        2) log_level="1" ;;
        3) log_level="2" ;;
        4) log_level="3" ;;
        *) 
            echo -e "${YELLOW}Invalid choice. Using default (1).${NC}" | tee -a "$LOG_FILE"
            log_level="1"
        ;;
    esac
    
    # Update global section if it exists
    if grep -q "\[global\]" "$smb_conf"; then
        # Update existing global section
        sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*workgroup[[:space:]]*=\).*/\1 $new_workgroup/" "$smb_conf"
        sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*server string[[:space:]]*=\).*/\1 $new_server_string/" "$smb_conf"
        
        # Add or update netbios name
        if grep -q "netbios name" "$smb_conf"; then
            sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*netbios name[[:space:]]*=\).*/\1 $netbios_name/" "$smb_conf"
        else
            sed -i "/\[global\]/a\\tnetbios name = $netbios_name" "$smb_conf"
        fi
        
        # Add or update log level
        if grep -q "log level" "$smb_conf"; then
            sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*log level[[:space:]]*=\).*/\1 $log_level/" "$smb_conf"
        else
            sed -i "/\[global\]/a\\tlog level = $log_level" "$smb_conf"
        fi
    else
        # Create new global section at the top of the file
        sed -i "1s/^/[global]\n\tworkgroup = $new_workgroup\n\tserver string = $new_server_string\n\tnetbios name = $netbios_name\n\tlog level = $log_level\n\n/" "$smb_conf"
    fi
    
    # Security settings
    local security_mode
    echo -e "${YELLOW}Select authentication mode:${NC}" | tee -a "$LOG_FILE"
    echo "1. User-level security (default, recommended)"
    echo "2. Domain security (Active Directory environment)"
    echo "3. Share-level security (legacy, not recommended)"
    
    echo -n "Enter your choice (1-3): "
    read -r sec_choice
    
    case $sec_choice in
        1) security_mode="user" ;;
        2) security_mode="domain" ;;
        3) security_mode="share" ;;
        *) 
            echo -e "${YELLOW}Invalid choice. Using default (user).${NC}" | tee -a "$LOG_FILE"
            security_mode="user"
        ;;
    esac
    
    # Add or update security setting
    if grep -q "security" "$smb_conf"; then
        sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*security[[:space:]]*=\).*/\1 $security_mode/" "$smb_conf"
    else
        sed -i "/\[global\]/a\\tsecurity = $security_mode" "$smb_conf"
    fi
    
    # Configure network settings
    local interfaces=""
    echo -e "${YELLOW}Current network interfaces:${NC}" | tee -a "$LOG_FILE"
    ip -o addr show 2>/dev/null | grep -v '^lo' | awk '{print $2 ": " $4}' || echo "Could not detect network interfaces"
    
    if ask_yes_no "Would you like to bind Samba to specific interfaces?"; then
        echo -n "Enter interface names separated by spaces (e.g., eth0 wlan0): "
        read -r interface_list
        
        if [ -n "$interface_list" ]; then
            interfaces="interfaces = $interface_list"
            if grep -q "interfaces" "$smb_conf"; then
                sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*interfaces[[:space:]]*=\).*/\1 $interface_list/" "$smb_conf"
            else
                sed -i "/\[global\]/a\\tinterfaces = $interface_list" "$smb_conf"
            fi
            
            # Add bind interfaces only
            if grep -q "bind interfaces only" "$smb_conf"; then
                sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*bind interfaces only[[:space:]]*=\).*/\1 yes/" "$smb_conf"
            else
                sed -i "/\[global\]/a\\tbind interfaces only = yes" "$smb_conf"
            fi
        fi
    else
        # If not binding to specific interfaces, ensure we're not restricting
        if grep -q "bind interfaces only" "$smb_conf"; then
            sed -i "/\[global\]/,/\[.*\]/ s/^\([[:space:]]*bind interfaces only[[:space:]]*=\).*/\1 no/" "$smb_conf"
        fi
    fi
    
    # Test configuration before restarting
    if command_exists testparm; then
        echo -e "${YELLOW}Testing Samba configuration...${NC}" | tee -a "$LOG_FILE"
        if ! testparm -s >/dev/null 2>&1; then
            echo -e "${RED}Samba configuration test failed! Reverting to backup...${NC}" | tee -a "$LOG_FILE"
            cp "$backup_file" "$smb_conf"
            return 1
        fi
    fi
    
    # Restart Samba service
    echo -e "${YELLOW}Restarting Samba services to apply new global settings...${NC}" | tee -a "$LOG_FILE"
    if ! systemctl restart smbd nmbd; then
        echo -e "${RED}Failed to restart Samba services. Reverting to backup...${NC}" | tee -a "$LOG_FILE"
        cp "$backup_file" "$smb_conf"
        return 1
    fi
    
    check_status "Applied and activated new Samba global settings" || return 1
    
    echo -e "${GREEN}Samba global settings configured successfully.${NC}" | tee -a "$LOG_FILE"
    return 0
}

# Function to create a Samba share with enhanced options
create_samba_share() {
    print_section_header "Creating New Samba Share"
    
    local share_name share_path comment share_type browseable guest_ok readonly valid_users writable create_dir
    
    # Get share name
    while true; do
        read -rp "Enter the name for the share (e.g., PublicShare): " share_name
        if [ -z "$share_name" ]; then
            echo -e "${RED}Share name cannot be empty.${NC}" | tee -a "$LOG_FILE"
        elif [[ "$share_name" =~ [[:space:]] ]]; then
            echo -e "${RED}Share name cannot contain spaces.${NC}" | tee -a "$LOG_FILE"
        elif [[ "$share_name" =~ [^a-zA-Z0-9_-] ]]; then
            echo -e "${RED}Share name can only contain letters, numbers, underscores, and hyphens.${NC}" | tee -a "$LOG_FILE"
        else
            # Check if share already exists
            if grep -q "^\[$share_name\]" "/etc/samba/smb.conf" 2>/dev/null; then
                echo -e "${RED}A share with this name already exists. Please choose a different name.${NC}" | tee -a "$LOG_FILE"
            else
                break
            fi
        fi
    done
    
    # Get share path
    while true; do
        read -rp "Enter the full path for the share directory: " share_path
        if [ -z "$share_path" ]; then
            echo -e "${RED}Share path cannot be empty.${NC}" | tee -a "$LOG_FILE"
        else
            break
        fi
    done
    
    # Create directory if needed
    if [ ! -d "$share_path" ]; then
        if ask_yes_no "Directory '$share_path' does not exist. Create it?"; then
            if ! mkdir -p "$share_path"; then
                echo -e "${RED}Failed to create directory $share_path. Check permissions.${NC}" | tee -a "$LOG_FILE"
                return 1
            fi
            check_status "Created directory $share_path" || return 1
        else
            echo -e "${YELLOW}Share configuration canceled. Directory does not exist.${NC}" | tee -a "$LOG_FILE"
            return 1
        fi
    fi
    
    # Get share description
    read -rp "Enter a description for the share (optional): " comment
    
    # Configure share type
    echo -e "${YELLOW}Select share type:${NC}" | tee -a "$LOG_FILE"
    echo "1. Disk share (standard file sharing)"
    echo "2. Printer share"
    echo "3. IPC share (inter-process communication)"
    
    local share_type_choice
    read -rp "Enter your choice (default: 1): " share_type_choice
    
    case $share_type_choice in
        2) share_type="printable = yes" ;;
        3) share_type="printable = no" ;;
        *) share_type="" ;; # Default for disk share
    esac
    
    # Configure browseable option
    if ask_yes_no "Should this share be visible in network browsers? (recommended: yes)"; then
        browseable="yes"
    else
        browseable="no"
    fi
    
    # Configure access options
    echo -e "${YELLOW}Select access type:${NC}" | tee -a "$LOG_FILE"
    echo "1. Public share (guest access, no authentication)"
    echo "2. User-based access (require authentication)"
    echo "3. Specific users only"
    
    local access_choice
    read -rp "Enter your choice (default: 2): " access_choice
    
    case $access_choice in
        1) 
            guest_ok="yes"
            valid_users=""
            ;;
        3) 
            guest_ok="no"
            echo -n "Enter usernames that can access this share (space-separated): "
            read -r valid_users_list
            if [ -n "$valid_users_list" ]; then
                valid_users="valid users = $valid_users_list"
            else
                valid_users=""
                echo -e "${YELLOW}No users specified. Defaulting to all authenticated users.${NC}" | tee -a "$LOG_FILE"
            fi
            ;;
        *) 
            guest_ok="no"
            valid_users=""
            ;;
    esac
    
    # Configure write permissions
    if ask_yes_no "Should this share be writable?"; then
        writable="yes"
        readonly="no"
    else
        writable="no"
        readonly="yes"
    fi
    
    # Set permissions based on share configuration
    echo -e "${YELLOW}Setting appropriate permissions for $share_path...${NC}" | tee -a "$LOG_FILE"
    
    if [ "$guest_ok" == "yes" ] && [ "$writable" == "yes" ]; then
        # Public writable share
        if ! chmod -R 0777 "$share_path"; then
            echo -e "${YELLOW}Warning: Failed to set permissions. Check ownership.${NC}" | tee -a "$LOG_FILE"
        fi
        if ! chown -R nobody:nogroup "$share_path" 2>/dev/null; then
            echo -e "${YELLOW}Warning: Failed to set ownership. Make sure user 'nobody' exists.${NC}" | tee -a "$LOG_FILE"
        fi
        check_status "Set public writable permissions for $share_path" || echo -e "${YELLOW}Warning: Permission setting failed.${NC}" | tee -a "$LOG_FILE"
    elif [ "$guest_ok" == "yes" ] && [ "$writable" == "no" ]; then
        # Public read-only share
        if ! chmod -R 0755 "$share_path"; then
            echo -e "${YELLOW}Warning: Failed to set permissions. Check ownership.${NC}" | tee -a "$LOG_FILE"
        fi
        if ! chown -R nobody:nogroup "$share_path" 2>/dev/null; then
            echo -e "${YELLOW}Warning: Failed to set ownership. Make sure user 'nobody' exists.${NC}" | tee -a "$LOG_FILE"
        fi
        check_status "Set public read-only permissions for $share_path" || echo -e "${YELLOW}Warning: Permission setting failed.${NC}" | tee -a "$LOG_FILE"
    elif [ "$writable" == "yes" ]; then
        # Private writable share
        if ! chmod -R 0770 "$share_path"; then
            echo -e "${YELLOW}Warning: Failed to set permissions. Check ownership.${NC}" | tee -a "$LOG_FILE"
        fi
        if [ -n "$valid_users" ]; then
            # Try to set ownership to first valid user
            first_user=$(echo "$valid_users_list" | awk '{print $1}')
            if id "$first_user" &>/dev/null; then
                if ! chown -R "$first_user":"$first_user" "$share_path"; then
                    echo -e "${YELLOW}Warning: Failed to set ownership to $first_user.${NC}" | tee -a "$LOG_FILE"
                fi
                check_status "Set ownership to $first_user for $share_path" || echo -e "${YELLOW}Warning: Ownership setting failed.${NC}" | tee -a "$LOG_FILE"
            else
                echo -e "${YELLOW}User $first_user does not exist. Keeping current ownership.${NC}" | tee -a "$LOG_FILE"
            fi
        fi
    else
        # Private read-only share
        if ! chmod -R 0750 "$share_path"; then
            echo -e "${YELLOW}Warning: Failed to set permissions. Check ownership.${NC}" | tee -a "$LOG_FILE"
        fi
    fi
    
    # Configure advanced options
    local advanced_options=""
    
    if ask_yes_no "Would you like to configure advanced options for this share?"; then
        # Hide files starting with dot
        if ask_yes_no "Hide files starting with a dot (hidden files)?"; then
            advanced_options="${advanced_options}   hide dot files = yes\n"
        else
            advanced_options="${advanced_options}   hide dot files = no\n"
        fi
        
        # Configure max connections
        echo -n "Maximum simultaneous connections (0 for unlimited, default): "
        read -r max_connections
        if [[ "$max_connections" =~ ^[0-9]+$ ]]; then
            advanced_options="${advanced_options}   max connections = $max_connections\n"
        fi
        
        # Force file creation mode
        if ask_yes_no "Force specific permissions for new files?"; then
            echo -n "Enter file mode in octal (e.g., 0644): "
            read -r file_mode
            if [[ "$file_mode" =~ ^0[0-7]{3}$ ]]; then
                advanced_options="${advanced_options}   force create mode = $file_mode\n"
            else
                echo -e "${YELLOW}Invalid file mode format. Skipping.${NC}" | tee -a "$LOG_FILE"
            fi
        fi
        
        # Force directory creation mode
        if ask_yes_no "Force specific permissions for new directories?"; then
            echo -n "Enter directory mode in octal (e.g., 0755): "
            read -r dir_mode
            if [[ "$dir_mode" =~ ^0[0-7]{3}$ ]]; then
                advanced_options="${advanced_options}   force directory mode = $dir_mode\n"
            else
                echo -e "${YELLOW}Invalid directory mode format. Skipping.${NC}" | tee -a "$LOG_FILE"
            fi
        fi
        
        # VFS Objects (recycle bin)
        if ask_yes_no "Would you like to enable the recycle bin for this share?"; then
            # Create recycle directory if it doesn't exist
            if ! mkdir -p "$share_path/.recycle" 2>/dev/null; then
                echo -e "${YELLOW}Warning: Could not create recycle directory.${NC}" | tee -a "$LOG_FILE"
            else
                if ! chmod 0777 "$share_path/.recycle" 2>/dev/null; then
                    echo -e "${YELLOW}Warning: Could not set permissions on recycle directory.${NC}" | tee -a "$LOG_FILE"
                fi
            fi
            
            advanced_options="${advanced_options}   vfs objects = recycle\n"
            advanced_options="${advanced_options}   recycle:repository = .recycle\n"
            advanced_options="${advanced_options}   recycle:keeptree = yes\n"
            advanced_options="${advanced_options}   recycle:versions = yes\n"
            advanced_options="${advanced_options}   recycle:touch = yes\n"
            advanced_options="${advanced_options}   recycle:maxsize = 0\n"
            advanced_options="${advanced_options}   recycle:exclude = *.tmp *.temp *.o *.obj\n"
            advanced_options="${advanced_options}   recycle:exclude_dir = /tmp /temp /cache\n"
        fi
    fi
    
    # Backup existing smb.conf
    local smb_conf="/etc/samba/smb.conf"
    local backup_file="${smb_conf}.bak.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$smb_conf" ]; then
        cp "$smb_conf" "$backup_file"
        echo "Created backup at $backup_file" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}Error: $smb_conf not found. Is Samba installed correctly?${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Append share configuration
    echo -e "\n${YELLOW}Adding share configuration to $smb_conf...${NC}" | tee -a "$LOG_FILE"
    {
        echo ""
        echo "[$share_name]"
        echo "   path = $share_path"
        if [ -n "$comment" ]; then
            echo "   comment = $comment"
        fi
        if [ -n "$share_type" ]; then
            echo "   $share_type"
        fi
        echo "   browseable = $browseable"
        echo "   guest ok = $guest_ok"
        echo "   read only = $readonly"
        echo "   writable = $writable"
        if [ -n "$valid_users" ]; then
            echo "   $valid_users"
        fi
        
        # If guest access is enabled for writable share, force user and group
        if [ "$guest_ok" == "yes" ] && [ "$writable" == "yes" ]; then
            echo "   force user = nobody"
            echo "   force group = nogroup"
        fi
        
        # Add any advanced options without using echo -e
        if [ -n "$advanced_options" ]; then
            echo -n "$advanced_options" | sed 's/\\n/\n/g'
        fi
    } >> "$smb_conf"
    
    check_status "Added share [$share_name] to $smb_conf" || return 1
    
    # Test the configuration
    if command_exists testparm; then
        echo -e "${YELLOW}Testing Samba configuration...${NC}" | tee -a "$LOG_FILE"
        if ! testparm -s >/dev/null 2>&1; then
            echo -e "${RED}Samba configuration test failed! Reverting changes...${NC}" | tee -a "$LOG_FILE"
            cp "$backup_file" "$smb_conf"
            return 1
        fi
    else
        echo -e "${YELLOW}Warning: testparm not found, skipping configuration test.${NC}" | tee -a "$LOG_FILE"
    fi
    
    # Restart Samba service
    echo -e "${YELLOW}Restarting Samba services...${NC}" | tee -a "$LOG_FILE"
    if ! systemctl restart smbd nmbd; then
        echo -e "${RED}Failed to restart Samba services. Reverting to backup...${NC}" | tee -a "$LOG_FILE"
        cp "$backup_file" "$smb_conf"
        return 1
    fi
    
    check_status "Restarted Samba services" || return 1
    
    echo -e "${GREEN}Samba share [$share_name] configured successfully.${NC}" | tee -a "$LOG_FILE"
    
    # Remind about Samba users if needed
    if [ "$guest_ok" == "no" ]; then
        echo -e "\n${YELLOW}IMPORTANT:${NC} Remember to add Samba users using 'sudo smbpasswd -a <username>'." | tee -a "$LOG_FILE"
        if ask_yes_no "Would you like to add Samba users now?"; then
            manage_samba_users
        fi
    fi
    
    return 0
}