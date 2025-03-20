#!/bin/bash
# output.sh - Output and summary functions
# Author: Haashim
# Date: March 20, 2025

# Function to display summary
display_summary() {
    local source_path="$1"
    local destination="$2"
    local transfer_success="$3"
    local verification_success="$4"
    local check_success="$5"
    
    echo ""
    echo -e "${COLOR_BLUE}========== MIGRATION SUMMARY ==========${COLOR_NC}"
    echo ""
    echo -e "Source repository: ${COLOR_YELLOW}$source_path${COLOR_NC}"
    echo -e "Destination: ${COLOR_YELLOW}$destination${COLOR_NC}"
    echo ""
    echo -e "Transfer status: $([ "$transfer_success" = "true" ] && echo -e "${COLOR_GREEN}SUCCESS${COLOR_NC}" || echo -e "${COLOR_RED}FAILED${COLOR_NC}")"
    echo -e "Verification status: $([ "$verification_success" = "true" ] && echo -e "${COLOR_GREEN}SUCCESS${COLOR_NC}" || echo -e "${COLOR_RED}NOT PERFORMED${COLOR_NC}")"
    echo -e "Repository check status: $([ "$check_success" = "true" ] && echo -e "${COLOR_GREEN}SUCCESS${COLOR_NC}" || echo -e "${COLOR_RED}NOT PERFORMED${COLOR_NC}")"
    echo ""
    echo -e "${COLOR_BLUE}========== NEXT STEPS ==========${COLOR_NC}"
    echo ""
    
    if [ "$transfer_success" = "true" ]; then
        echo "1. Update any backup scripts or cron jobs to point to the new repository location:"
        echo "   Old path: $source_path"
        echo "   New path: $destination"
        echo ""
        echo "2. Test creating a new backup to the new location:"
        if [ "$IS_REMOTE" = "true" ]; then
            local remote_host="${destination%%:*}"
            local remote_path="${destination#*:}"
            echo "   borg create ${remote_host}:${remote_path}::newbackup /path/to/backup"
        else
            echo "   borg create ${destination}::newbackup /path/to/backup"
        fi
        echo ""
        echo "3. If this was a migration (not just a copy), you can remove the old repository"
        echo "   after verifying the new one works correctly:"
        echo "   rm -rf $source_path"
    else
        echo "The transfer was not fully successful. Please check the errors above and try again."
    fi
    
    echo ""
}

# Function to print a progress table
print_progress_table() {
    local total="$1"
    local current="$2"
    local width=50
    
    # Calculate percentage
    local percent=$((current * 100 / total))
    
    # Print progress bar
    create_progress_bar "$percent" "$width"
    echo -e " (${current}/${total})"
}

# Function to print a step-by-step guide
print_step_guide() {
    local current_step="$1"
    local total_steps="$2"
    local step_name="$3"
    
    echo -e "${COLOR_BLUE}Step ${current_step}/${total_steps}: ${step_name}${COLOR_NC}"
}

# Function to print recommendations
print_recommendations() {
    echo ""
    echo -e "${COLOR_BLUE}Recommendations:${COLOR_NC}"
    echo "• Always keep at least two copies of critical data"
    echo "• Test your backups regularly by attempting recovery"
    echo "• Consider using encryption for sensitive data"
    echo "• Set up regular backup schedules using cron or systemd timers"
    echo "• Store offsite copies for disaster recovery"
}

# Function to print warning message with critical information
print_critical_warning() {
    local message="$1"
    
    echo ""
    echo -e "${COLOR_RED}!!! CRITICAL WARNING !!!${COLOR_NC}"
    echo -e "${COLOR_YELLOW}$message${COLOR_NC}"
    echo ""
}

# Function to print successful completion message
print_completion() {
    local operation="$1"
    
    echo ""
    echo -e "${COLOR_GREEN}✓ $operation completed successfully!${COLOR_NC}"
    echo ""
}