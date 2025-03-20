#!/bin/bash
# repository.sh - Repository management functions
# Author: Haashim
# Date: March 20, 2025

# Function to check if a path is a valid Borg repository
is_borg_repo() {
    local repo_path="$1"
    
    log_info "Validating Borg repository at $repo_path..."
    
    if [ ! -e "$repo_path" ]; then
        log_error "Path does not exist: $repo_path"
        return 1
    fi
    
    if [ ! -d "$repo_path" ]; then
        log_error "Path is not a directory: $repo_path"
        return 1
    fi
    
    # Check for basic Borg repository structure
    if [ ! -e "$repo_path/config" ] || [ ! -e "$repo_path/data" ] || [ ! -d "$repo_path/data" ]; then
        log_error "Path does not appear to be a Borg repository: $repo_path"
        log_info "Missing expected Borg repository files or directories."
        return 1
    fi
    
    # Try to get info from the repository
    if borg info "$repo_path" &> /dev/null; then
        log_success "Successfully validated Borg repository."
        return 0
    else
        log_error "Failed to validate Borg repository. It may be corrupted or require a passphrase."
        
        if ask_yes_no "Do you need to enter a passphrase for this repository?"; then
            # Try again with manual passphrase
            read -s -p "Enter repository passphrase: " passphrase
            echo ""
            
            if BORG_PASSPHRASE="$passphrase" borg info "$repo_path" &> /dev/null; then
                log_success "Repository validated with passphrase."
                # Save passphrase for later use
                export BORG_PASSPHRASE="$passphrase"
                return 0
            else
                log_error "Failed to validate repository even with passphrase."
                return 1
            fi
        fi
        
        return 1
    fi
}

# Function to verify repository integrity
check_repository_integrity() {
    local repo_path="$1"
    local is_remote="$2"
    
    log_info "Verifying repository integrity..."
    
    if [ "$is_remote" = "true" ]; then
        # Remote repository
        local remote_host="${repo_path%%:*}"
        local remote_path="${repo_path#*:}"
        
        log_info "Checking repository on remote host $remote_host..."
        if ssh "$remote_host" "command -v borg &> /dev/null && borg check \"$remote_path\""; then
            log_success "Repository check passed on remote host."
            return 0
        else
            log_warning "Could not verify repository on remote host."
            log_info "This could be because Borg is not installed there or the repository is damaged."
            
            if ask_yes_no "Would you like to try to install Borg on the remote host?"; then
                help_install_remote_borg "$remote_host"
                # Try again after installation
                if ssh "$remote_host" "command -v borg &> /dev/null && borg check \"$remote_path\""; then
                    log_success "Repository check passed on remote host."
                    return 0
                else
                    log_error "Repository check failed even after installing Borg."
                    return 1
                fi
            else
                log_info "Please verify the repository manually."
                return 1
            fi
        fi
    else
        # Local repository
        if borg check --verbose "$repo_path"; then
            log_success "Repository verification completed successfully."
            return 0
        else
            log_error "Repository verification failed. The repository may be corrupted."
            
            if ask_yes_no "Would you like to attempt to repair the repository?"; then
                log_warning "Attempting to repair repository. This may take a while..."
                if borg check --repair "$repo_path"; then
                    log_success "Repository repair completed successfully."
                    return 0
                else
                    log_error "Repository repair failed."
                    return 1
                fi
            fi
            return 1
        fi
    fi
}

# Function to lock a repository
lock_repository() {
    local repo_path="$1"
    
    log_info "Locking repository at $repo_path..."
    
    if borg with-lock "$repo_path" true; then
        log_success "Repository locked successfully."
        return 0
    else
        log_error "Failed to lock repository."
        return 1
    fi
}

# Function to unlock a repository
unlock_repository() {
    local repo_path="$1"
    
    log_info "Unlocking repository at $repo_path..."
    
    if borg break-lock "$repo_path"; then
        log_success "Repository unlocked successfully."
        return 0
    else
        log_error "Failed to unlock repository."
        return 1
    fi
}

# Function to save migration state
save_migration_state() {
    local source_path="$1"
    local destination="$2"
    
    log_info "Saving migration state..."
    
    # Get source repo ID
    local repo_id=$(borg info --json "$source_path" 2>/dev/null | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)
    
    # Create state entry
    echo "{
        \"source\": \"$source_path\",
        \"destination\": \"$destination\",
        \"timestamp\": \"$(date +%s)\",
        \"repo_id\": \"$repo_id\",
        \"status\": \"completed\"
    }" > "$STATE_FILE"
    
    log_info "Migration state saved to $STATE_FILE"
    return 0
}

# Function to check for previous migration of this repository
check_previous_migration() {
    local source_path="$1"
    local destination="$2"
    
    if [ ! -f "$STATE_FILE" ]; then
        return 1
    fi
    
    local stored_source=$(grep -o '"source": "[^"]*"' "$STATE_FILE" | cut -d'"' -f4)
    local stored_dest=$(grep -o '"destination": "[^"]*"' "$STATE_FILE" | cut -d'"' -f4)
    
    if [ "$stored_source" = "$source_path" ] && [ "$stored_dest" = "$destination" ]; then
        # Get saved repo ID
        local saved_repo_id=$(grep -o '"repo_id": "[^"]*"' "$STATE_FILE" | cut -d'"' -f4)
        
        # Get destination repo ID if possible
        local dest_repo_id=""
        if [ "$IS_REMOTE" = "true" ]; then
            dest_repo_id=$(ssh "${destination%%:*}" "command -v borg &> /dev/null && borg info --json \"${destination#*:}\" 2>/dev/null | grep -o '\"id\": \"[^\"]*\"' | head -1 | cut -d'\"' -f4")
        else
            dest_repo_id=$(borg info --json "$destination" 2>/dev/null | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)
        fi
        
        if [ -n "$dest_repo_id" ] && [ -n "$saved_repo_id" ] && [ "$dest_repo_id" = "$saved_repo_id" ]; then
            log_success "Detected previous successful migration of this repository."
            return 0
        fi
    fi
    
    return 1
}