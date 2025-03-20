#!/bin/bash
# borg-migrate.sh - Main script for Borg repository migration
# Author: Haashim
# Date: March 20, 2025

# Determine the script directory regardless of how it's called
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration and library files
source "${SCRIPT_DIR}/config/defaults.sh"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/setup.sh"
source "${SCRIPT_DIR}/lib/repository.sh"
source "${SCRIPT_DIR}/lib/filesystem.sh"
source "${SCRIPT_DIR}/lib/transfer.sh"
source "${SCRIPT_DIR}/lib/output.sh"

# Function to handle cleanup on exit
cleanup() {
    log_info "Performing cleanup operations..."
    
    # Unlock repository if it was locked
    if [[ "$LOCK_REPO" == "true" && -n "$SOURCE_PATH" ]]; then
        unlock_repository "$SOURCE_PATH"
    fi
    
    log_info "Script execution completed."
}

# Set up trap to ensure cleanup runs on exit
trap cleanup EXIT

# Main script entry point
main() {
    clear
    print_banner
    
    parse_arguments "$@"
    prompt_for_missing_parameters
    display_transfer_details
    
    # Confirm details before proceeding
    if ! ask_yes_no "Does this look correct? Do you want to proceed?"; then
        log_info "Operation cancelled by user."
        exit 0
    fi
    
    # Perform pre-transfer checks
    log_info "Running pre-transfer checks..."
    run_pre_transfer_checks
    
    # Lock repository if requested
    if [[ "$LOCK_REPO" == "true" ]]; then
        lock_repository "$SOURCE_PATH"
    fi
    
    # Perform the transfer
    perform_transfer
    
    # Verify and check repository if needed
    if [[ "$TRANSFER_SUCCESS" == "true" && "$DRY_RUN" == "false" ]]; then
        if verify_transfer "$SOURCE_PATH" "$DESTINATION" "$IS_REMOTE"; then
            VERIFICATION_SUCCESS="true"
        else
            VERIFICATION_SUCCESS="false"
        fi
        
        if [[ "$CHECK_AFTER" == "true" ]]; then
            if check_repository_integrity "$DESTINATION" "$IS_REMOTE"; then
                CHECK_SUCCESS="true"
                save_migration_state "$SOURCE_PATH" "$DESTINATION"
            else
                CHECK_SUCCESS="false"
            fi
        fi
    fi
    
    # Display summary of operations
    display_summary "$SOURCE_PATH" "$DESTINATION" "$TRANSFER_SUCCESS" "$VERIFICATION_SUCCESS" "$CHECK_SUCCESS"
    
    # If this was a dry-run, ask if they want to do the real thing
    handle_dry_run_completion
}

# Parse command line arguments
parse_arguments() {
    # Initialize variables with defaults
    SOURCE_PATH=""
    DESTINATION=""
    CHECK_AFTER="$DEFAULT_CHECK_AFTER"
    DRY_RUN="$DEFAULT_DRY_RUN"
    VERBOSE="$DEFAULT_VERBOSE"
    LOCK_REPO="$DEFAULT_LOCK_REPO"
    IS_REMOTE="false"
    TRANSFER_SUCCESS="false"
    VERIFICATION_SUCCESS="false"
    CHECK_SUCCESS="false"
    
    # Show help if requested
    if [[ $# -gt 0 && ("$1" == "-h" || "$1" == "--help") ]]; then
        show_usage
        exit 0
    fi
    
    # Process positional arguments if provided
    if [[ $# -ge 2 ]]; then
        SOURCE_PATH="$1"
        DESTINATION="$2"
        shift 2
        
        # Parse options
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -c|--check)
                    CHECK_AFTER="true"
                    ;;
                -d|--dry-run)
                    DRY_RUN="true"
                    ;;
                -v|--verbose)
                    VERBOSE="true"
                    ;;
                -l|--lock)
                    LOCK_REPO="true"
                    ;;
                *)
                    log_warning "Unknown option: $1"
                    ;;
            esac
            shift
        done
    fi
    
    # Check if destination is remote
    if [[ "$DESTINATION" == *":"* ]]; then
        IS_REMOTE="true"
        REMOTE_HOST="${DESTINATION%%:*}"
        REMOTE_PATH="${DESTINATION#*:}"
    fi
}

# Prompt for missing parameters if not provided via command line
prompt_for_missing_parameters() {
    # If no source path provided, prompt for it
    if [[ -z "$SOURCE_PATH" ]]; then
        log_info "No source repository specified."
        read -p "Enter the path to your Borg repository: " SOURCE_PATH
        
        # Validate input
        if [[ -z "$SOURCE_PATH" ]]; then
            log_error "No source repository provided. Exiting."
            exit 1
        fi
    fi
    
    # If no destination provided, prompt for it
    if [[ -z "$DESTINATION" ]]; then
        log_info "No destination specified."
        log_info "For local transfer, enter a path like: /backup/path"
        log_info "For remote transfer, enter: user@remote-pc:/backup/path"
        read -p "Enter destination: " DESTINATION
        
        # Validate input
        if [[ -z "$DESTINATION" ]]; then
            log_error "No destination provided. Exiting."
            exit 1
        fi
        
        # Check if destination is remote
        if [[ "$DESTINATION" == *":"* ]]; then
            IS_REMOTE="true"
            REMOTE_HOST="${DESTINATION%%:*}"
            REMOTE_PATH="${DESTINATION#*:}"
        fi
    fi
    
    # If options not specified, interactively ask for them
    if [[ -z "$OPTIONS_SPECIFIED" ]]; then
        if ask_yes_no "Perform repository check after transfer?" "y"; then
            CHECK_AFTER="true"
        fi
        
        if ask_yes_no "Lock repository during transfer (recommended)?" "y"; then
            LOCK_REPO="true"
        fi
        
        if ask_yes_no "Run in dry-run mode first (recommended)?" "y"; then
            DRY_RUN="true"
        fi
        
        if ask_yes_no "Enable verbose output?" "n"; then
            VERBOSE="true"
        fi
    fi
}

# Run all pre-transfer checks
run_pre_transfer_checks() {
    # Verify Borg is installed locally
    check_local_borg
    
    # Check for and offer to install helper packages
    install_helper_packages
    
    # If remote, check remote connectivity and Borg installation
    if [[ "$IS_REMOTE" == "true" ]]; then
        check_remote_borg "$REMOTE_HOST"
    fi
    
    # Verify source path is a valid Borg repository
    if ! is_borg_repo "$SOURCE_PATH"; then
        if ! ask_yes_no "Source is not a valid Borg repository. Continue anyway?"; then
            log_info "Operation cancelled by user."
            exit 1
        fi
        log_warning "Proceeding with an invalid source repository may cause problems."
    fi
    
    # Check for destination conflicts
    if ! check_destination_conflict "$DESTINATION" "$IS_REMOTE"; then
        log_info "Operation cancelled to prevent data loss."
        exit 1
    fi
    
    # Ensure destination directory exists
    if ! ensure_directory_exists "$DESTINATION" "$IS_REMOTE"; then
        if ! ask_yes_no "Failed to create destination directory. Continue anyway?"; then
            log_info "Operation cancelled by user."
            exit 1
        fi
        log_warning "Proceeding without proper destination directory may cause problems."
    fi
    
    # Check available disk space
    check_disk_space "$SOURCE_PATH" "$DESTINATION" "$IS_REMOTE"
    
    # Test transfer speed
    check_transfer_speed "$DESTINATION" "$IS_REMOTE"
}

# Perform the transfer operation
perform_transfer() {
    # Create rsync options
    RSYNC_OPTS="-az --checksum"
    if [[ "$DRY_RUN" == "true" ]]; then
        RSYNC_OPTS="$RSYNC_OPTS --dry-run"
        log_info "Running in DRY-RUN mode. No actual changes will be made."
    fi
    if [[ "$VERBOSE" == "true" ]]; then
        RSYNC_OPTS="$RSYNC_OPTS -v"
    fi
    
    log_info "Starting transfer of Borg repository from '$SOURCE_PATH' to '$DESTINATION'"
    log_info "This may take a while depending on the repository size..."
    
    # Try transfer up to 3 times if needed
    for attempt in {1..3}; do
        if [[ $attempt -gt 1 ]]; then
            log_info "Retry attempt $attempt of 3..."
        fi
        
        # Run the transfer
        if transfer_with_progress "$SOURCE_PATH" "$DESTINATION" "$RSYNC_OPTS"; then
            log_success "Transfer completed successfully."
            TRANSFER_SUCCESS="true"
            break
        else
            local rsync_exit=$?
            log_error "Transfer failed with exit code $rsync_exit"
            
            if [[ $attempt -lt 3 ]]; then
                if ! ask_yes_no "Would you like to retry the transfer?"; then
                    TRANSFER_SUCCESS="false"
                    break
                fi
            else
                TRANSFER_SUCCESS="false"
            fi
        fi
    done
}

# Handle dry-run completion and prompt to run actual transfer
handle_dry_run_completion() {
    if [[ "$DRY_RUN" == "true" && "$TRANSFER_SUCCESS" == "true" ]]; then
        if ask_yes_no "Dry run completed successfully. Would you like to perform the actual transfer now?"; then
            # Set dry-run to false and rerun the script with all the same parameters
            DRY_RUN="false"
            OPTIONS=""
            [[ "$CHECK_AFTER" == "true" ]] && OPTIONS="$OPTIONS -c"
            [[ "$VERBOSE" == "true" ]] && OPTIONS="$OPTIONS -v"
            [[ "$LOCK_REPO" == "true" ]] && OPTIONS="$OPTIONS -l"
            
            exec "$0" "$SOURCE_PATH" "$DESTINATION" $OPTIONS
        else
            log_info "Dry run completed. Exiting without performing actual transfer."
        fi
    fi
}

# Run the main function with all arguments
main "$@"