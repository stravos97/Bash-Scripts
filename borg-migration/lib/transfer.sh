#!/bin/bash
# transfer.sh - Transfer-related functions
# Author: Haashim
# Date: March 20, 2025

# Function to check transfer speeds (helpful for large repos)
check_transfer_speed() {
    local destination="$1"
    local is_remote="$2"
    
    log_info "Testing transfer speed..."
    
    # Create a test file
    dd if=/dev/urandom of="$TEMP_DIR/borg_test_file" bs=1M count=$TRANSFER_TEST_SIZE &> /dev/null
    
    if [ "$is_remote" = "true" ]; then
        # Remote transfer speed test
        local remote_host="${destination%%:*}"
        local remote_path="${destination#*:}"
        
        # Time the transfer
        local start_time=$(date +%s)
        rsync -a "$TEMP_DIR/borg_test_file" "$remote_host:/tmp/" &> /dev/null
        local end_time=$(date +%s)
        
        # Calculate speed
        local duration=$((end_time - start_time))
        if [ "$duration" -eq 0 ]; then
            duration=1
        fi
        local speed=$((TRANSFER_TEST_SIZE / duration))
        
        log_info "Estimated transfer speed: ${speed} MB/s"
        
        # Estimate total transfer time
        local source_size_mb=$(du -sm "$SOURCE_PATH" | awk '{print $1}')
        local estimated_time=$((source_size_mb / speed))
        local estimated_time_human
        
        if [ "$estimated_time" -gt 3600 ]; then
            estimated_time_human="$((estimated_time / 3600)) hours $((estimated_time % 3600 / 60)) minutes"
        elif [ "$estimated_time" -gt 60 ]; then
            estimated_time_human="$((estimated_time / 60)) minutes $((estimated_time % 60)) seconds"
        else
            estimated_time_human="$estimated_time seconds"
        fi
        
        log_info "Estimated transfer time: $estimated_time_human"
        
        # Clean up
        ssh "$remote_host" "rm -f /tmp/borg_test_file" &> /dev/null
    else
        # Local transfer speed test
        local dest_dir=$(dirname "$destination")
        
        # Time the transfer
        local start_time=$(date +%s)
        cp "$TEMP_DIR/borg_test_file" "$dest_dir/borg_test_file" &> /dev/null
        local end_time=$(date +%s)
        
        # Calculate speed
        local duration=$((end_time - start_time))
        if [ "$duration" -eq 0 ]; then
            duration=1
        fi
        local speed=$((TRANSFER_TEST_SIZE / duration))
        
        log_info "Estimated transfer speed: ${speed} MB/s"
        
        # Estimate total transfer time
        local source_size_mb=$(du -sm "$SOURCE_PATH" | awk '{print $1}')
        local estimated_time=$((source_size_mb / speed))
        local estimated_time_human
        
        if [ "$estimated_time" -gt 3600 ]; then
            estimated_time_human="$((estimated_time / 3600)) hours $((estimated_time % 3600 / 60)) minutes"
        elif [ "$estimated_time" -gt 60 ]; then
            estimated_time_human="$((estimated_time / 60)) minutes $((estimated_time % 60)) seconds"
        else
            estimated_time_human="$estimated_time seconds"
        fi
        
        log_info "Estimated transfer time: $estimated_time_human"
        
        # Clean up
        rm -f "$dest_dir/borg_test_file" &> /dev/null
    fi
    
    # Clean up local test file
    rm -f "$TEMP_DIR/borg_test_file" &> /dev/null
    
    return 0
}

# Function to handle transfer with improved progress display
transfer_with_progress() {
    local source_path="$1"
    local destination="$2"
    local rsync_opts="$3"
    
    # Get total size
    local total_size=$(du -sb "$source_path" | awk '{print $1}')
    local total_size_human=$(du -sh "$source_path" | awk '{print $1}')
    
    log_info "Total size to transfer: $total_size_human"
    log_info "Transfer in progress..."
    
    # Detect rsync version for advanced progress support
    local rsync_version=$(rsync --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    local version_parts=(${rsync_version//./ })
    local major=${version_parts[0]}
    local minor=${version_parts[1]}
    
    # Modern rsync (3.1.0+) has better progress display with progress2
    if [ "$major" -gt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -ge 1 ]); then
        log_info "Using enhanced progress display..."
        rsync $rsync_opts --info=progress2 "$source_path/" "$destination/"
    else
        # For older rsync versions, use standard progress with a custom progress bar
        log_info "Using standard progress display..."
        
        # Use progress indicator
        if command_exists pv && [ "$IS_REMOTE" = "false" ]; then
            # For local transfers with pv installed, use it for better visualization
            log_info "Using enhanced visualization with pv..."
            tar -C "$(dirname "$source_path")" -cf - "$(basename "$source_path")" | \
            pv -s "$total_size" -p -t -e -r | \
            tar -xf - -C "$(dirname "$destination")" 
            
            # Fix path if needed
            if [ -d "$(dirname "$destination")/$(basename "$source_path")" ] && [ "$(dirname "$destination")/$(basename "$source_path")" != "$destination" ]; then
                cp -a "$(dirname "$destination")/$(basename "$source_path")"/* "$destination/"
                rm -rf "$(dirname "$destination")/$(basename "$source_path")"
            fi
        else
            # Use standard rsync with progress
            rsync $rsync_opts --progress "$source_path/" "$destination/"
        fi
    fi
    
    return $?
}

# Function to verify the transferred data
verify_transfer() {
    local source_path="$1"
    local destination="$2"
    local is_remote="$3"
    
    log_info "Verifying transfer accuracy..."
    
    # For local transfers, use diff
    if [ "$is_remote" = "false" ]; then
        if diff -r --brief "$source_path" "$destination" > /dev/null; then
            log_success "Transfer verification successful. All files match!"
            return 0
        else
            log_error "Transfer verification failed. Some files do not match."
            
            if ask_yes_no "Would you like to see the differences?"; then
                diff -r --brief "$source_path" "$destination"
            fi
            
            if ask_yes_no "Would you like to try the transfer again?"; then
                return 1  # Signal to retry
            else
                return 2  # Signal not to retry
            fi
        fi
    else
        # For remote transfers, we'll need to use rsync to compare
        log_info "Comparing checksums of source and destination..."
        if rsync -anvc "$source_path/" "$destination/" | grep -q "^>f"; then
            log_error "Transfer verification failed. Some files do not match."
            
            if ask_yes_no "Would you like to see the differences?"; then
                rsync -anvc "$source_path/" "$destination/"
            fi
            
            if ask_yes_no "Would you like to try the transfer again?"; then
                return 1  # Signal to retry
            else
                return 2  # Signal not to retry
            fi
        else
            log_success "Transfer verification successful. All files match!"
            return 0
        fi
    fi
}