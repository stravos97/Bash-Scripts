#!/bin/bash
# common.sh - Common utility functions
# Author: Haashim
# Date: March 20, 2025

# Print banner and script title
print_banner() {
    echo -e "${COLOR_BLUE}============================================${COLOR_NC}"
    echo -e "${COLOR_BLUE}   Interactive Borg Backup Migration Tool   ${COLOR_NC}"
    echo -e "${COLOR_BLUE}============================================${COLOR_NC}"
    echo ""
}

# Function to display usage information
show_usage() {
    echo -e "${COLOR_BLUE}Interactive Borg Backup Migration Script${COLOR_NC}"
    echo -e "This script helps you safely transfer Borg repositories between computers."
    echo ""
    echo "Usage: $SCRIPT_NAME [source_path] [destination] [options]"
    echo ""
    echo "Options:"
    echo "  -c, --check       Perform repository check after transfer"
    echo "  -d, --dry-run     Show what would be transferred without actually transferring"
    echo "  -v, --verbose     Enable verbose output"
    echo "  -l, --lock        Lock repository during transfer (prevents corruption)"
    echo "  -h, --help        Display this help message"
    echo ""
    echo "Example: $SCRIPT_NAME /path/to/borg/repo user@remote-pc:/backup/path -c -l"
    echo ""
    echo "If parameters are omitted, the script will prompt for them interactively."
}

# Logging functions with different severity levels
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_NC} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_NC} $1"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_NC} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1"
}

# Function to ask yes/no questions
ask_yes_no() {
    local question="$1"
    local default="${2:-y}"
    
    local prompt
    if [ "$default" = "y" ]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi
    
    read -p "$question $prompt " answer
    
    if [ -z "$answer" ]; then
        answer=$default
    fi
    
    case "${answer,,}" in
        y|yes)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to prompt for input with a default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    
    read -p "$prompt [$default]: " input
    echo "${input:-$default}"
}

# Function to check if a command exists on the system
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to create a visual progress bar
create_progress_bar() {
    local percent=$1
    local width=${2:-50}
    
    # Calculate the number of characters to fill
    local filled=$(($width * $percent / 100))
    local empty=$(($width - $filled))
    
    # Create the progress bar
    local bar=""
    for ((i=0; i<$filled; i++)); do
        bar="${bar}█"
    done
    
    for ((i=0; i<$empty; i++)); do
        bar="${bar}░"
    done
    
    echo -ne "[${bar}] ${percent}%"
}

# Function to display transfer details for confirmation
display_transfer_details() {
    echo ""
    echo -e "${COLOR_BLUE}Transfer Details:${COLOR_NC}"
    echo -e "Source: ${COLOR_YELLOW}$SOURCE_PATH${COLOR_NC}"
    echo -e "Destination: ${COLOR_YELLOW}$DESTINATION${COLOR_NC}"
    echo -e "Mode: ${COLOR_YELLOW}$([ "$IS_REMOTE" = "true" ] && echo "Remote" || echo "Local")${COLOR_NC}"
    echo -e "Options:"
    echo -e "  - Check after transfer: ${COLOR_YELLOW}$([ "$CHECK_AFTER" = "true" ] && echo "Yes" || echo "No")${COLOR_NC}"
    echo -e "  - Dry run: ${COLOR_YELLOW}$([ "$DRY_RUN" = "true" ] && echo "Yes" || echo "No")${COLOR_NC}"
    echo -e "  - Verbose output: ${COLOR_YELLOW}$([ "$VERBOSE" = "true" ] && echo "Yes" || echo "No")${COLOR_NC}"
    echo -e "  - Lock repository: ${COLOR_YELLOW}$([ "$LOCK_REPO" = "true" ] && echo "Yes" || echo "No")${COLOR_NC}"
    echo ""
}