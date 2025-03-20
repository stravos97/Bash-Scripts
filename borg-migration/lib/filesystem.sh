#!/bin/bash
# filesystem.sh - Directory and space management functions
# Author: Haashim
# Date: March 20, 2025

# Function to create parent directory if needed
ensure_directory_exists() {
    local path="$1"
    local is_remote="$2"
    
    log_info "Ensuring destination directory exists..."
    
    if [ "$is_remote" = "true" ]; then
        # Remote path - extract host and path
        local host="${path%%:*}"
        local remote_path="${path#*:}"
        
        # Create parent directory on remote host
        if ssh "$host" "mkdir -p \"$(dirname \"$remote_path\")\""; then
            log_success "Remote destination directory created/verified."
            return 0
        else
            log_error "Failed to create remote destination directory."
            
            # Try to get more information
            local ssh_output=$(ssh "$host" "ls -ld \"$(dirname \"$remote_path\")\" 2>&1 || echo 'Directory does not exist'")
            log_info "Remote directory info: $ssh_output"
            
            if ask_yes_no "Would you like to retry with sudo?"; then
                if ssh "$host" "sudo mkdir -p \"$(dirname \"$remote_path\")\""; then
                    log_success "Remote destination directory created with sudo."
                    return 0
                else
                    log_error "Failed to create remote destination directory even with sudo."
                    return 1
                fi
            fi
            
            return 1
        fi
    else
        # Local path
        if mkdir -p "$(dirname "$path")"; then
            log_success "Local destination directory created/verified."
            return 0
        else
            log_error "Failed to create local destination directory."
            
            # Try with sudo
            if ask_yes_no "Would you like to retry with sudo?"; then
                if sudo mkdir -p "$(dirname "$path")"; then
                    log_success "Local destination directory created with sudo."
                    return 0
                else
                    log_error "Failed to create local destination directory even with sudo."
                    return 1
                fi
            fi
            
            return 1
        fi
    fi
}

# Function to check available disk space
check_disk_space() {
    local source_path="$1"
    local destination="$2"
    local is_remote="$3"
    
    log_info "Checking available disk space..."
    
    # Get source repository size
    local source_size=$(du -s "$source_path" | awk '{print $1}')
    local source_size_human=$(du -sh "$source_path" | awk '{print $1}')
    
    log_info "Source repository size: $source_size_human"
    
    # Check destination space
    if [ "$is_remote" = "true" ]; then
        # Remote destination
        local remote_host="${destination%%:*}"
        local remote_path="${destination#*:}"
        
        # Get available space on remote system
        local remote_available=$(ssh "$remote_host" "df -k \"$(dirname \"$remote_path\")\" | tail -1 | awk '{print \$4}'")
        local remote_available_human=$(ssh "$remote_host" "df -h \"$(dirname \"$remote_path\")\" | tail -1 | awk '{print \$4}'")
        
        log_info "Available space on remote destination: $remote_available_human"
        
        if [ "$remote_available" -lt "$source_size" ]; then
            log_error "Insufficient space on remote destination."
            log_info "Required: $source_size_human, Available: $remote_available_human"
            
            if ! ask_yes_no "Continue anyway? (Not recommended)"; then
                log_info "Operation cancelled by user."
                exit 1
            fi
        else
            log_success "Sufficient space available on remote destination."
        fi
    else
        # Local destination
        local dest_dir=$(dirname "$destination")
        local local_available=$(df -k "$dest_dir" | tail -1 | awk '{print $4}')
        local local_available_human=$(df -h "$dest_dir" | tail -1 | awk '{print $4}')
        
        log_info "Available space on local destination: $local_available_human"
        
        if [ "$local_available" -lt "$source_size" ]; then
            log_error "Insufficient space on local destination."
            log_info "Required: $source_size_human, Available: $local_available_human"
            
            if ! ask_yes_no "Continue anyway? (Not recommended)"; then
                log_info "Operation cancelled by user."
                exit 1
            fi
        else
            log_success "Sufficient space available on local destination."
        fi
    fi
    
    return 0
}

# Function to check for existing repositories at destination
check_destination_conflict() {
    local destination="$1"
    local is_remote="$2"
    
    log_info "Checking for existing data at destination..."
    
    # First check if this is a repeat of a previous successful migration
    if check_previous_migration "$SOURCE_PATH" "$destination"; then
        if ask_yes_no "This exact migration appears to have been completed successfully before. Skip transfer?"; then
            log_info "Skipping transfer as requested."
            # Jump to summary
            display_summary "$SOURCE_PATH" "$destination" "true" "true" "true"
            exit 0
        else
            log_info "Proceeding with transfer despite previous completion."
        fi
    fi
    
    if [ "$is_remote" = "true" ]; then
        # Remote destination
        local remote_host="${destination%%:*}"
        local remote_path="${destination#*:}"
        
        if ssh "$remote_host" "[ -e \"$remote_path\" ] && [ -d \"$remote_path\" ] && [ \"\$(ls -A \"$remote_path\" 2>/dev/null)\" ]"; then
            log_warning "Destination directory exists and is not empty!"
            
            if ask_yes_no "Would you like to see the contents?"; then
                ssh "$remote_host" "ls -la \"$remote_path\""
            fi
            
            if ask_yes_no "Do you want to overwrite the existing data?"; then
                if ask_yes_no "Are you ABSOLUTELY SURE? This cannot be undone!"; then
                    log_warning "Proceeding with overwrite as requested."
                    return 0
                else
                    log_info "Overwrite cancelled."
                    return 1
                fi
            else
                log_info "Operation cancelled to prevent data loss."
                return 1
            fi
        else
            log_success "Destination directory is empty or doesn't exist yet."
            return 0
        fi
    else
        # Local destination
        if [ -e "$destination" ] && [ -d "$destination" ] && [ "$(ls -A "$destination" 2>/dev/null)" ]; then
            log_warning "Destination directory exists and is not empty!"
            
            if ask_yes_no "Would you like to see the contents?"; then
                ls -la "$destination"
            fi
            
            if ask_yes_no "Do you want to overwrite the existing data?"; then
                if ask_yes_no "Are you ABSOLUTELY SURE? This cannot be undone!"; then
                    log_warning "Proceeding with overwrite as requested."
                    return 0
                else
                    log_info "Overwrite cancelled."
                    return 1
                fi
            else
                log_info "Operation cancelled to prevent data loss."
                return 1
            fi
        else
            log_success "Destination directory is empty or doesn't exist yet."
            return 0
        fi
    fi
}