#!/bin/bash
# setup.sh - Setup and validation functions
# Author: Haashim
# Date: March 20, 2025

# Install helper packages if needed and available
install_helper_packages() {
    log_info "Checking for helper packages..."
    
    local packages_to_install=()
    
    # Check for required/suggested packages
    for pkg in "${SUGGESTED_PACKAGES[@]}"; do
        if ! command_exists "$pkg"; then
            packages_to_install+=("$pkg")
        fi
    done
    
    # If we have packages to install and package manager is available
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        log_info "Some helpful packages are missing: ${packages_to_install[*]}"
        
        if command_exists apt-get; then
            if ask_yes_no "Would you like to install them using apt-get?"; then
                sudo apt-get update && sudo apt-get install -y "${packages_to_install[@]}"
                log_success "Packages installed successfully."
            fi
        elif command_exists dnf; then
            if ask_yes_no "Would you like to install them using dnf?"; then
                sudo dnf install -y "${packages_to_install[@]}"
                log_success "Packages installed successfully."
            fi
        elif command_exists yum; then
            if ask_yes_no "Would you like to install them using yum?"; then
                sudo yum install -y "${packages_to_install[@]}"
                log_success "Packages installed successfully."
            fi
        elif command_exists pacman; then
            if ask_yes_no "Would you like to install them using pacman?"; then
                sudo pacman -Sy --noconfirm "${packages_to_install[@]}"
                log_success "Packages installed successfully."
            fi
        elif command_exists brew; then
            if ask_yes_no "Would you like to install them using brew?"; then
                brew install "${packages_to_install[@]}"
                log_success "Packages installed successfully."
            fi
        else
            log_warning "Could not find a package manager to install: ${packages_to_install[*]}"
            log_info "You may want to install them manually for better experience."
        fi
    else
        log_success "All required packages are already installed."
    fi
}

# Function to check if Borg is installed locally
check_local_borg() {
    log_info "Checking if Borg is installed on this system..."
    if ! command_exists borg; then
        log_error "Borg backup is not installed on this system."
        log_info "Please install Borg before using this script: https://borgbackup.org/install.html"
        
        if ask_yes_no "Would you like to continue anyway?"; then
            log_warning "Continuing without Borg may lead to incomplete functionality."
            return 0
        else
            log_info "Operation cancelled by user."
            exit 1
        fi
    else
        local borg_version=$(borg --version | cut -d' ' -f2)
        log_success "Borg $borg_version is installed."
        return 0
    fi
}

# Function to check if Borg is installed on a remote system
check_remote_borg() {
    local remote_host="$1"
    
    log_info "Checking if Borg is installed on remote system ($remote_host)..."
    
    # First check SSH connectivity
    if ! ssh -o BatchMode=yes -o ConnectTimeout=$SSH_TIMEOUT "$remote_host" echo "SSH connection successful" &> /dev/null; then
        log_error "Cannot connect to remote host via SSH."
        log_info "Please ensure:"
        log_info "  1. The remote host is online"
        log_info "  2. SSH service is running on the remote host"
        log_info "  3. You have proper SSH credentials (keys or password)"
        
        if ask_yes_no "Would you like to try setting up SSH keys now?"; then
            setup_ssh_keys "$remote_host"
        else
            if ! ask_yes_no "Continue anyway?"; then
                log_info "Operation cancelled by user."
                exit 1
            fi
            return 1
        fi
    fi
    
    # Check if Borg is installed
    if ! ssh "$remote_host" "command -v borg &> /dev/null"; then
        log_warning "Borg backup is not installed on the remote system ($remote_host)."
        log_info "Some functions like repository checking will not work until Borg is installed there."
        
        if ask_yes_no "Would you like to help install Borg on the remote system?"; then
            help_install_remote_borg "$remote_host"
        elif ! ask_yes_no "Continue without Borg on the remote system?"; then
            log_info "Operation cancelled by user."
            exit 1
        fi
        return 1
    else
        local remote_version=$(ssh "$remote_host" "borg --version | cut -d' ' -f2")
        log_success "Borg $remote_version is installed on remote system."
        return 0
    fi
}

# Function to set up SSH keys
setup_ssh_keys() {
    local remote_host="$1"
    
    log_info "Setting up SSH keys for $remote_host..."
    
    # Check if SSH key exists
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        log_info "No SSH key found. Generating a new one..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    fi
    
    log_info "Copying SSH public key to remote host..."
    ssh-copy-id "$remote_host"
    
    if [ $? -eq 0 ]; then
        log_success "SSH key setup completed successfully."
    else
        log_error "SSH key setup failed."
        if ! ask_yes_no "Continue anyway?"; then
            log_info "Operation cancelled by user."
            exit 1
        fi
    fi
}

# Function to help install Borg on remote system
help_install_remote_borg() {
    local remote_host="$1"
    
    log_info "Attempting to help install Borg on $remote_host..."
    
    # Check remote OS
    local os_type=$(ssh "$remote_host" "cat /etc/os-release | grep '^ID=' | cut -d= -f2")
    os_type=${os_type//\"/}
    
    case "$os_type" in
        ubuntu|debian)
            log_info "Detected Debian/Ubuntu system. Using apt..."
            ssh "$remote_host" "sudo apt-get update && sudo apt-get install -y borgbackup"
            ;;
        fedora|centos|rhel)
            log_info "Detected Fedora/CentOS/RHEL system. Using dnf/yum..."
            ssh "$remote_host" "sudo dnf install -y borgbackup || sudo yum install -y borgbackup"
            ;;
        arch)
            log_info "Detected Arch Linux. Using pacman..."
            ssh "$remote_host" "sudo pacman -Sy borgbackup"
            ;;
        *)
            log_warning "Unknown or unsupported OS: $os_type"
            log_info "Please install Borg manually on the remote system: https://borgbackup.org/install.html"
            return 1
            ;;
    esac
    
    if ssh "$remote_host" "command -v borg &> /dev/null"; then
        log_success "Borg was successfully installed on the remote system."
        return 0
    else
        log_error "Failed to install Borg on the remote system."
        return 1
    fi
}