#!/bin/bash
# user_management.sh - Functions for user management
# This module handles creating users and configuring user-specific settings

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Function to create a new user with sudo privileges
create_new_user() {
    print_section_header "Creating New User"

    # Get username
    local valid_username=false
    local new_username=""
    
    while [ "$valid_username" = false ]; do
        echo -n "Enter new username: "
        read -r new_username

        if validate_username "$new_username"; then
            valid_username=true
        fi
    done

    # Get password
    local new_password=""
    local confirm_password=""
    
    echo -n "Enter password for $new_username: "
    read -s new_password
    echo

    echo -n "Confirm password: "
    read -s confirm_password
    echo

    if [ "$new_password" != "$confirm_password" ]; then
        echo -e "${RED}Passwords do not match.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    # Create user
    echo -e "\n${YELLOW}Creating user '$new_username' with home directory...${NC}" | tee -a "$LOG_FILE"
    useradd -m -s /bin/bash "$new_username"
    echo "$new_username:$new_password" | chpasswd

    # Add user to sudo group
    echo -e "${YELLOW}Adding '$new_username' to sudo group...${NC}" | tee -a "$LOG_FILE"
    usermod -aG sudo "$new_username"

    # Copy setup script to new user's home directory if it's not already there
    local new_user_script="/home/$new_username/$(basename "$MAIN_SCRIPT")"
    if [ ! -f "$new_user_script" ]; then
        cp "$MAIN_SCRIPT" "$new_user_script"
        chown "$new_username":"$new_username" "$new_user_script"
        chmod +x "$new_user_script"
        echo -e "The setup script has been copied to ${YELLOW}$new_user_script${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${GREEN}Script already exists at $new_user_script${NC}" | tee -a "$LOG_FILE"
    fi

    echo -e "${GREEN}User '$new_username' has been created successfully with sudo privileges.${NC}" | tee -a "$LOG_FILE"

    # Set up SSH key for the new user
    if ask_yes_no "Would you like to set up SSH public key authentication for the new user?"; then
        local key_method=""
        echo -n "How would you like to provide the SSH key? (paste/file): "
        read -r key_method

        setup_ssh_key "$new_username" "$key_method"
    fi

    # Provide instructions for the new user
    echo -e "${YELLOW}Setup complete for new user '$new_username'.${NC}" | tee -a "$LOG_FILE"
    echo -e "${GREEN}To continue with system setup:${NC}" | tee -a "$LOG_FILE"
    echo -e "1. Log out of this session" | tee -a "$LOG_FILE"
    echo -e "2. Log in as user '$new_username'" | tee -a "$LOG_FILE"
    echo -e "3. Run the script with: ${YELLOW}sudo bash $new_user_script${NC}" | tee -a "$LOG_FILE"

    if ask_yes_no "Would you like to continue system setup with the current user instead?"; then
        return 0
    else
        echo -e "${GREEN}Exiting. Please log in as '$new_username' to complete setup.${NC}" | tee -a "$LOG_FILE"
        exit 0
    fi
}

# Function to set up SSH with public key authentication for a user
setup_ssh_key() {
    local username="$1"
    local key_source="$2" # "paste" or "file"
    local user_home

    # Get user's home directory
    user_home=$(eval echo ~"$username")

    print_section_header "Setting up SSH Public Key Authentication for user '$username'"

    # Create .ssh directory if it doesn't exist
    if [ ! -d "$user_home/.ssh" ]; then
        mkdir -p "$user_home/.ssh"
        check_status "Created .ssh directory" || return 1
    else
        echo -e "${GREEN}.ssh directory already exists.${NC}" | tee -a "$LOG_FILE"
    fi

    local ssh_key=""

    if [ "$key_source" = "paste" ]; then
        # Get public key from user input
        echo -e "${YELLOW}Please paste your SSH public key (starts with ssh-rsa, ssh-ed25519, etc.):${NC}" | tee -a "$LOG_FILE"
        read -r ssh_key

        # Validate the key
        if ! validate_ssh_key "$ssh_key"; then
            echo -e "${RED}SSH key setup failed.${NC}" | tee -a "$LOG_FILE"
            return 1
        fi
    elif [ "$key_source" = "file" ]; then
        echo -e "${YELLOW}Enter the path to your public key file:${NC}" | tee -a "$LOG_FILE"
        read -r key_path

        if [ ! -f "$key_path" ]; then
            echo -e "${RED}File not found: $key_path${NC}" | tee -a "$LOG_FILE"
            return 1
        fi

        ssh_key=$(cat "$key_path")

        # Validate the key
        if ! validate_ssh_key "$ssh_key"; then
            echo -e "${RED}SSH key setup failed.${NC}" | tee -a "$LOG_FILE"
            return 1
        fi
    else
        echo -e "${RED}Invalid key source.${NC}" | tee -a "$LOG_FILE"
        return 1
    fi

    # Check if authorized_keys file exists
    local auth_keys_file="$user_home/.ssh/authorized_keys"
    if [ ! -f "$auth_keys_file" ]; then
        touch "$auth_keys_file"
        echo "Created new authorized_keys file" | tee -a "$LOG_FILE"
    fi

    # Check if key already exists in authorized_keys
    if key_exists "$ssh_key" "$auth_keys_file"; then
        echo -e "${GREEN}SSH key already exists in authorized_keys. Skipping addition.${NC}" | tee -a "$LOG_FILE"
    else
        # Add key to authorized_keys
        echo "$ssh_key" >> "$auth_keys_file"
        check_status "Added SSH key to authorized_keys" || return 1
    fi

    # Fix permissions
    chmod 700 "$user_home/.ssh"
    chmod 600 "$auth_keys_file"
    chown -R "$username":"$username" "$user_home/.ssh"
    check_status "Set correct permissions for SSH files" || return 1

    echo -e "${GREEN}SSH public key authentication configured successfully for user '$username'.${NC}" | tee -a "$LOG_FILE"

    return 0
}

# Function to setup SSH keys for the current real user
setup_current_user_ssh() {
    local real_user=$(get_real_user)
    
    if [ -n "$real_user" ] && [[ "$real_user" != "root" ]]; then
        if ask_yes_no "Would you like to set up SSH public key authentication for user '$real_user'?"; then
            local key_method=""
            echo -n "How would you like to provide the SSH key? (paste/file): "
            read -r key_method

            setup_ssh_key "$real_user" "$key_method"
        fi
    fi
}