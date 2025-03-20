#!/bin/bash
# Interactive script to move Borg backup repositories from one PC to another
# with extensive validation and safety checks
# Author: Haashim
# Date: March 20, 2025

set -e  # Exit immediately if any command fails

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage information
show_usage() {
    echo -e "${BLUE}Interactive Borg Backup Migration Script${NC}"
    echo -e "This script helps you safely transfer Borg repositories between computers."
    echo ""
    echo "Usage: $0 [source_path] [destination] [options]"
    echo ""
    echo "Options:"
    echo "  -c, --check       Perform repository check after transfer"
    echo "  -d, --dry-run     Show what would be transferred without actually transferring"
    echo "  -v, --verbose     Enable verbose output"
    echo "  -l, --lock        Lock repository during transfer (prevents corruption)"
    echo "  -h, --help        Display this help message"
    echo ""
    echo "Example: $0 /path/to/borg/repo user@remote-pc:/backup/path -c -l"
    echo ""
    echo "If parameters are omitted, the script will prompt for them interactively."
    exit 1
}

# Function to display a nicely formatted message
print_message() {
    local type="$1"
    local message="$2"

    case "$type" in
        "info")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "success")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "warning")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "error")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
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

# Install helper packages if needed and available
install_helper_packages() {
    print_message "info" "Checking for helper packages..."

    local packages_to_install=()

    # Check for pv (pipe viewer) for better progress visualization
    if ! command_exists pv; then
        packages_to_install+=("pv")
    fi

    # Check for rsync
    if ! command_exists rsync; then
        packages_to_install+=("rsync")
    fi

    # If we have packages to install and package manager is available
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        print_message "info" "Some helpful packages are missing: ${packages_to_install[*]}"

        if command_exists apt-get; then
            if ask_yes_no "Would you like to install them using apt-get?"; then
                sudo apt-get update && sudo apt-get install -y "${packages_to_install[@]}"
                print_message "success" "Packages installed successfully."
            fi
        elif command_exists dnf; then
            if ask_yes_no "Would you like to install them using dnf?"; then
                sudo dnf install -y "${packages_to_install[@]}"
                print_message "success" "Packages installed successfully."
            fi
        elif command_exists yum; then
            if ask_yes_no "Would you like to install them using yum?"; then
                sudo yum install -y "${packages_to_install[@]}"
                print_message "success" "Packages installed successfully."
            fi
        elif command_exists pacman; then
            if ask_yes_no "Would you like to install them using pacman?"; then
                sudo pacman -Sy --noconfirm "${packages_to_install[@]}"
                print_message "success" "Packages installed successfully."
            fi
        elif command_exists brew; then
            if ask_yes_no "Would you like to install them using brew?"; then
                brew install "${packages_to_install[@]}"
                print_message "success" "Packages installed successfully."
            fi
        else
            print_message "warning" "Could not find a package manager to install: ${packages_to_install[*]}"
            print_message "info" "You may want to install them manually for better experience."
        fi
    else
        print_message "success" "All required packages are already installed."
    fi
}

# Function to check if Borg is installed locally
check_local_borg() {
    print_message "info" "Checking if Borg is installed on this system..."
    if ! command_exists borg; then
        print_message "error" "Borg backup is not installed on this system."
        print_message "info" "Please install Borg before using this script: https://borgbackup.org/install.html"

        if ask_yes_no "Would you like to continue anyway?"; then
            print_message "warning" "Continuing without Borg may lead to incomplete functionality."
            return 0
        else
            print_message "info" "Operation cancelled by user."
            exit 1
        fi
    else
        print_message "success" "Borg $(borg --version | cut -d' ' -f2) is installed."
        return 0
    fi
}

# Function to check if Borg is installed on a remote system
check_remote_borg() {
    local remote_host="$1"

    print_message "info" "Checking if Borg is installed on remote system ($remote_host)..."

    # First check SSH connectivity
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$remote_host" echo "SSH connection successful" &> /dev/null; then
        print_message "error" "Cannot connect to remote host via SSH."
        print_message "info" "Please ensure:"
        print_message "info" "  1. The remote host is online"
        print_message "info" "  2. SSH service is running on the remote host"
        print_message "info" "  3. You have proper SSH credentials (keys or password)"

        if ask_yes_no "Would you like to try setting up SSH keys now?"; then
            setup_ssh_keys "$remote_host"
        else
            if ! ask_yes_no "Continue anyway?"; then
                print_message "info" "Operation cancelled by user."
                exit 1
            fi
            return 1
        fi
    fi

    # Check if Borg is installed
    if ! ssh "$remote_host" "command -v borg &> /dev/null"; then
        print_message "warning" "Borg backup is not installed on the remote system ($remote_host)."
        print_message "info" "Some functions like repository checking will not work until Borg is installed there."

        if ask_yes_no "Would you like to help install Borg on the remote system?"; then
            help_install_remote_borg "$remote_host"
        elif ! ask_yes_no "Continue without Borg on the remote system?"; then
            print_message "info" "Operation cancelled by user."
            exit 1
        fi
        return 1
    else
        local remote_version=$(ssh "$remote_host" "borg --version | cut -d' ' -f2")
        print_message "success" "Borg $remote_version is installed on remote system."
        return 0
    fi
}

# Function to set up SSH keys
setup_ssh_keys() {
    local remote_host="$1"

    print_message "info" "Setting up SSH keys for $remote_host..."

    # Check if SSH key exists
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        print_message "info" "No SSH key found. Generating a new one..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    fi

    print_message "info" "Copying SSH public key to remote host..."
    ssh-copy-id "$remote_host"

    if [ $? -eq 0 ]; then
        print_message "success" "SSH key setup completed successfully."
    else
        print_message "error" "SSH key setup failed."
        if ! ask_yes_no "Continue anyway?"; then
            print_message "info" "Operation cancelled by user."
            exit 1
        fi
    fi
}

# Function to help install Borg on remote system
help_install_remote_borg() {
    local remote_host="$1"

    print_message "info" "Attempting to help install Borg on $remote_host..."

    # Check remote OS
    local os_type=$(ssh "$remote_host" "cat /etc/os-release | grep '^ID=' | cut -d= -f2")
    os_type=${os_type//\"/}

    case "$os_type" in
        ubuntu|debian)
            print_message "info" "Detected Debian/Ubuntu system. Using apt..."
            ssh "$remote_host" "sudo apt-get update && sudo apt-get install -y borgbackup"
            ;;
        fedora|centos|rhel)
            print_message "info" "Detected Fedora/CentOS/RHEL system. Using dnf/yum..."
            ssh "$remote_host" "sudo dnf install -y borgbackup || sudo yum install -y borgbackup"
            ;;
        arch)
            print_message "info" "Detected Arch Linux. Using pacman..."
            ssh "$remote_host" "sudo pacman -Sy borgbackup"
            ;;
        *)
            print_message "warning" "Unknown or unsupported OS: $os_type"
            print_message "info" "Please install Borg manually on the remote system: https://borgbackup.org/install.html"
            return 1
            ;;
    esac

    if ssh "$remote_host" "command -v borg &> /dev/null"; then
        print_message "success" "Borg was successfully installed on the remote system."
        return 0
    else
        print_message "error" "Failed to install Borg on the remote system."
        return 1
    fi
}

# Function to check if a path is a valid Borg repository
is_borg_repo() {
    local repo_path="$1"

    print_message "info" "Validating Borg repository at $repo_path..."

    if [ ! -e "$repo_path" ]; then
        print_message "error" "Path does not exist: $repo_path"
        return 1
    fi

    if [ ! -d "$repo_path" ]; then
        print_message "error" "Path is not a directory: $repo_path"
        return 1
    fi

    # Check for basic Borg repository structure
    if [ ! -e "$repo_path/config" ] || [ ! -e "$repo_path/data" ] || [ ! -d "$repo_path/data" ]; then
        print_message "error" "Path does not appear to be a Borg repository: $repo_path"
        print_message "info" "Missing expected Borg repository files or directories."
        return 1
    fi

    # Try to get info from the repository
    if borg info "$repo_path" &> /dev/null; then
        print_message "success" "Successfully validated Borg repository."
        return 0
    else
        print_message "error" "Failed to validate Borg repository. It may be corrupted or require a passphrase."

        if ask_yes_no "Do you need to enter a passphrase for this repository?"; then
            # Try again with manual passphrase
            if BORG_PASSPHRASE=$(read -s -p "Enter repository passphrase: " passphrase; echo "$passphrase") borg info "$repo_path" &> /dev/null; then
                print_message "success" "Repository validated with passphrase."
                # Save passphrase for later use
                export BORG_PASSPHRASE
                return 0
            else
                print_message "error" "Failed to validate repository even with passphrase."
                return 1
            fi
        fi

        return 1
    fi
}

# Function to verify repository integrity
check_repository() {
    local repo_path="$1"

    print_message "info" "Verifying repository integrity at $repo_path..."

    if borg check --verbose "$repo_path"; then
        print_message "success" "Repository verification completed successfully."
        return 0
    else
        print_message "error" "Repository verification failed. The repository may be corrupted."
        if ask_yes_no "Would you like to attempt to repair the repository?"; then
            print_message "warning" "Attempting to repair repository. This may take a while..."
            if borg check --repair "$repo_path"; then
                print_message "success" "Repository repair completed successfully."
                return 0
            else
                print_message "error" "Repository repair failed."
                return 1
            fi
        fi
        return 1
    fi
}

# Function to lock/unlock a repository
lock_repository() {
    local repo_path="$1"
    local action="$2"  # "lock" or "unlock"

    print_message "info" "${action^}ing repository at $repo_path..."

    if [ "$action" = "lock" ]; then
        if borg with-lock "$repo_path" true; then
            print_message "success" "Repository locked successfully."
            return 0
        else
            print_message "error" "Failed to lock repository."
            return 1
        fi
    else
        if borg break-lock "$repo_path"; then
            print_message "success" "Repository unlocked successfully."
            return 0
        else
            print_message "error" "Failed to unlock repository."
            return 1
        fi
    fi
}

# Function to create parent directory if needed
ensure_directory_exists() {
    local path="$1"
    local is_remote="$2"

    print_message "info" "Ensuring destination directory exists..."

    if [ "$is_remote" = "true" ]; then
        # Remote path - extract host and path
        local host="${path%%:*}"
        local remote_path="${path#*:}"

        # Create parent directory on remote host
        if ssh "$host" "mkdir -p \"$(dirname \"$remote_path\")\""; then
            print_message "success" "Remote destination directory created/verified."
            return 0
        else
            print_message "error" "Failed to create remote destination directory."

            # Try to get more information
            local ssh_output=$(ssh "$host" "ls -ld \"$(dirname \"$remote_path\")\" 2>&1 || echo 'Directory does not exist'")
            print_message "info" "Remote directory info: $ssh_output"

            if ask_yes_no "Would you like to retry with sudo?"; then
                if ssh "$host" "sudo mkdir -p \"$(dirname \"$remote_path\")\""; then
                    print_message "success" "Remote destination directory created with sudo."
                    return 0
                else
                    print_message "error" "Failed to create remote destination directory even with sudo."
                    return 1
                fi
            fi

            return 1
        fi
    else
        # Local path
        if mkdir -p "$(dirname "$path")"; then
            print_message "success" "Local destination directory created/verified."
            return 0
        else
            print_message "error" "Failed to create local destination directory."

            # Try with sudo
            if ask_yes_no "Would you like to retry with sudo?"; then
                if sudo mkdir -p "$(dirname "$path")"; then
                    print_message "success" "Local destination directory created with sudo."
                    return 0
                else
                    print_message "error" "Failed to create local destination directory even with sudo."
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

    print_message "info" "Checking available disk space..."

    # Get source repository size
    local source_size=$(du -s "$source_path" | awk '{print $1}')
    local source_size_human=$(du -sh "$source_path" | awk '{print $1}')

    print_message "info" "Source repository size: $source_size_human"

    # Check destination space
    if [ "$is_remote" = "true" ]; then
        # Remote destination
        local remote_host="${destination%%:*}"
        local remote_path="${destination#*:}"

        # Get available space on remote system
        local remote_available=$(ssh "$remote_host" "df -k \"$(dirname \"$remote_path\")\" | tail -1 | awk '{print \$4}'")
        local remote_available_human=$(ssh "$remote_host" "df -h \"$(dirname \"$remote_path\")\" | tail -1 | awk '{print \$4}'")

        print_message "info" "Available space on remote destination: $remote_available_human"

        if [ "$remote_available" -lt "$source_size" ]; then
            print_message "error" "Insufficient space on remote destination."
            print_message "info" "Required: $source_size_human, Available: $remote_available_human"

            if ! ask_yes_no "Continue anyway? (Not recommended)"; then
                print_message "info" "Operation cancelled by user."
                exit 1
            fi
        else
            print_message "success" "Sufficient space available on remote destination."
        fi
    else
        # Local destination
        local dest_dir=$(dirname "$destination")
        local local_available=$(df -k "$dest_dir" | tail -1 | awk '{print $4}')
        local local_available_human=$(df -h "$dest_dir" | tail -1 | awk '{print $4}')

        print_message "info" "Available space on local destination: $local_available_human"

        if [ "$local_available" -lt "$source_size" ]; then
            print_message "error" "Insufficient space on local destination."
            print_message "info" "Required: $source_size_human, Available: $local_available_human"

            if ! ask_yes_no "Continue anyway? (Not recommended)"; then
                print_message "info" "Operation cancelled by user."
                exit 1
            fi
        else
            print_message "success" "Sufficient space available on local destination."
        fi
    fi

    return 0
}

# Function to check if a command exists on the system
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check transfer speeds (helpful for large repos)
check_transfer_speed() {
    local destination="$1"
    local is_remote="$2"

    print_message "info" "Testing transfer speed..."

    # Create a 10MB test file
    dd if=/dev/urandom of=/tmp/borg_test_file bs=1M count=10 &> /dev/null

    if [ "$is_remote" = "true" ]; then
        # Remote transfer speed test
        local remote_host="${destination%%:*}"
        local remote_path="${destination#*:}"

        # Time the transfer
        local start_time=$(date +%s)
        rsync -a /tmp/borg_test_file "$remote_host:/tmp/" &> /dev/null
        local end_time=$(date +%s)

        # Calculate speed
        local duration=$((end_time - start_time))
        if [ "$duration" -eq 0 ]; then
            duration=1
        fi
        local speed=$((10 / duration))

        print_message "info" "Estimated transfer speed: ${speed} MB/s"

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

        print_message "info" "Estimated transfer time: $estimated_time_human"

        # Clean up
        ssh "$remote_host" "rm -f /tmp/borg_test_file" &> /dev/null
    else
        # Local transfer speed test
        local dest_dir=$(dirname "$destination")

        # Time the transfer
        local start_time=$(date +%s)
        cp /tmp/borg_test_file "$dest_dir/borg_test_file" &> /dev/null
        local end_time=$(date +%s)

        # Calculate speed
        local duration=$((end_time - start_time))
        if [ "$duration" -eq 0 ]; then
            duration=1
        fi
        local speed=$((10 / duration))

        print_message "info" "Estimated transfer speed: ${speed} MB/s"

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

        print_message "info" "Estimated transfer time: $estimated_time_human"

        # Clean up
        rm -f "$dest_dir/borg_test_file" &> /dev/null
    fi

    # Clean up local test file
    rm -f /tmp/borg_test_file &> /dev/null

    return 0
}

# Function to create and read state file
manage_state_file() {
    local action="$1"  # "read", "write", or "check"
    local source_path="$2"
    local destination="$3"
    local state_file="$HOME/.borg_migration_state.json"

    case "$action" in
        "read")
            if [ -f "$state_file" ]; then
                # Return stored state
                cat "$state_file"
                return 0
            else
                return 1
            fi
            ;;
        "write")
            # Get source repo ID
            local repo_id=$(borg info --json "$source_path" 2>/dev/null | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

            # Create state entry
            echo "{
                \"source\": \"$source_path\",
                \"destination\": \"$destination\",
                \"timestamp\": \"$(date +%s)\",
                \"repo_id\": \"$repo_id\",
                \"status\": \"completed\"
            }" > "$state_file"
            print_message "info" "Migration state saved to $state_file"
            return 0
            ;;
        "check")
            if [ -f "$state_file" ]; then
                local stored_source=$(grep -o '"source": "[^"]*"' "$state_file" | cut -d'"' -f4)
                local stored_dest=$(grep -o '"destination": "[^"]*"' "$state_file" | cut -d'"' -f4)

                if [ "$stored_source" = "$source_path" ] && [ "$stored_dest" = "$destination" ]; then
                    # Get saved repo ID
                    local saved_repo_id=$(grep -o '"repo_id": "[^"]*"' "$state_file" | cut -d'"' -f4)

                    # Get destination repo ID if possible
                    local dest_repo_id=""
                    if [ "$IS_REMOTE" = "true" ]; then
                        dest_repo_id=$(ssh "${destination%%:*}" "command -v borg &> /dev/null && borg info --json \"${destination#*:}\" 2>/dev/null | grep -o '\"id\": \"[^\"]*\"' | head -1 | cut -d'\"' -f4")
                    else
                        dest_repo_id=$(borg info --json "$destination" 2>/dev/null | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)
                    fi

                    if [ -n "$dest_repo_id" ] && [ -n "$saved_repo_id" ] && [ "$dest_repo_id" = "$saved_repo_id" ]; then
                        print_message "success" "Detected previous successful migration of this repository."
                        return 0
                    fi
                fi
            fi
            return 1
            ;;
    esac
}

# Function to check for existing repositories at destination
check_destination_conflict() {
    local destination="$1"
    local is_remote="$2"

    print_message "info" "Checking for existing data at destination..."

    # First check if this is a repeat of a previous successful migration
    if manage_state_file "check" "$SOURCE_PATH" "$destination"; then
        if ask_yes_no "This exact migration appears to have been completed successfully before. Skip transfer?"; then
            print_message "info" "Skipping transfer as requested."
            # Jump to summary
            display_summary "$SOURCE_PATH" "$destination" "true" "true" "true"
            exit 0
        else
            print_message "info" "Proceeding with transfer despite previous completion."
        fi
    fi

    if [ "$is_remote" = "true" ]; then
        # Remote destination
        local remote_host="${destination%%:*}"
        local remote_path="${destination#*:}"

        if ssh "$remote_host" "[ -e \"$remote_path\" ] && [ -d \"$remote_path\" ] && [ \"\$(ls -A \"$remote_path\" 2>/dev/null)\" ]"; then
            print_message "warning" "Destination directory exists and is not empty!"

            if ask_yes_no "Would you like to see the contents?"; then
                ssh "$remote_host" "ls -la \"$remote_path\""
            fi

            if ask_yes_no "Do you want to overwrite the existing data?"; then
                if ask_yes_no "Are you ABSOLUTELY SURE? This cannot be undone!"; then
                    print_message "warning" "Proceeding with overwrite as requested."
                    return 0
                else
                    print_message "info" "Overwrite cancelled."
                    return 1
                fi
            else
                print_message "info" "Operation cancelled to prevent data loss."
                return 1
            fi
        else
            print_message "success" "Destination directory is empty or doesn't exist yet."
            return 0
        fi
    else
        # Local destination
        if [ -e "$destination" ] && [ -d "$destination" ] && [ "$(ls -A "$destination" 2>/dev/null)" ]; then
            print_message "warning" "Destination directory exists and is not empty!"

            if ask_yes_no "Would you like to see the contents?"; then
                ls -la "$destination"
            fi

            if ask_yes_no "Do you want to overwrite the existing data?"; then
                if ask_yes_no "Are you ABSOLUTELY SURE? This cannot be undone!"; then
                    print_message "warning" "Proceeding with overwrite as requested."
                    return 0
                else
                    print_message "info" "Overwrite cancelled."
                    return 1
                fi
            else
                print_message "info" "Operation cancelled to prevent data loss."
                return 1
            fi
        else
            print_message "success" "Destination directory is empty or doesn't exist yet."
            return 0
        fi
    fi
}

# Function to handle transfer with improved progress display
transfer_with_progress() {
    local source_path="$1"
    local destination="$2"
    local rsync_opts="$3"

    # Get total size
    local total_size=$(du -sb "$source_path" | awk '{print $1}')
    local total_size_human=$(du -sh "$source_path" | awk '{print $1}')

    print_message "info" "Total size to transfer: $total_size_human"
    print_message "info" "Transfer in progress..."

    # Detect rsync version for advanced progress support
    local rsync_version=$(rsync --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    local version_parts=(${rsync_version//./ })
    local major=${version_parts[0]}
    local minor=${version_parts[1]}

    # Modern rsync (3.1.0+) has better progress display with progress2
    if [ "$major" -gt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -ge 1 ]); then
        print_message "info" "Using enhanced progress display..."
        rsync $rsync_opts --info=progress2 "$source_path/" "$destination/"
    else
        # For older rsync versions, use standard progress with a custom progress bar
        print_message "info" "Using standard progress display..."

        # Use progress indicator
        if command_exists pv && [ "$IS_REMOTE" = "false" ]; then
            # For local transfers with pv installed, use it for better visualization
            print_message "info" "Using enhanced visualization with pv..."
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

# Function to verify the transferred data
verify_transfer() {
    local source_path="$1"
    local destination="$2"
    local is_remote="$3"

    print_message "info" "Verifying transfer accuracy..."

    # For local transfers, use diff
    if [ "$is_remote" = "false" ]; then
        if diff -r --brief "$source_path" "$destination" > /dev/null; then
            print_message "success" "Transfer verification successful. All files match!"
            return 0
        else
            print_message "error" "Transfer verification failed. Some files do not match."

            if ask_yes_no "Would you like to see the differences?"; then
                diff -r --brief "$source_path" "$destination"
            fi

            if ask_yes_no "Would you like to try the transfer again?"; then
                return 2  # Signal to retry
            else
                return 1
            fi
        fi
    else
        # For remote transfers, we'll need to use rsync to compare
        print_message "info" "Comparing checksums of source and destination..."
        if rsync -anvc "$source_path/" "$destination/" | grep -q "^>f"; then
            print_message "error" "Transfer verification failed. Some files do not match."

            if ask_yes_no "Would you like to see the differences?"; then
                rsync -anvc "$source_path/" "$destination/"
            fi

            if ask_yes_no "Would you like to try the transfer again?"; then
                return 2  # Signal to retry
            else
                return 1
            fi
        else
            print_message "success" "Transfer verification successful. All files match!"
            return 0
        fi
    fi
}

# Function to display summary
display_summary() {
    local source_path="$1"
    local destination="$2"
    local transfer_success="$3"
    local verification_success="$4"
    local check_success="$5"

    echo ""
    echo -e "${BLUE}========== MIGRATION SUMMARY ==========${NC}"
    echo ""
    echo -e "Source repository: ${YELLOW}$source_path${NC}"
    echo -e "Destination: ${YELLOW}$destination${NC}"
    echo ""
    echo -e "Transfer status: $([ "$transfer_success" = "true" ] && echo -e "${GREEN}SUCCESS${NC}" || echo -e "${RED}FAILED${NC}")"
    echo -e "Verification status: $([ "$verification_success" = "true" ] && echo -e "${GREEN}SUCCESS${NC}" || echo -e "${RED}NOT PERFORMED${NC}")"
    echo -e "Repository check status: $([ "$check_success" = "true" ] && echo -e "${GREEN}SUCCESS${NC}" || echo -e "${RED}NOT PERFORMED${NC}")"
    echo ""
    echo -e "${BLUE}========== NEXT STEPS ==========${NC}"
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

# Main script begins here
clear
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   Interactive Borg Backup Migration Tool   ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Parse command line arguments
if [ $# -gt 0 ] && [ "$1" = "-h" -o "$1" = "--help" ]; then
    show_usage
fi

# Initialize variables
SOURCE_PATH=""
DESTINATION=""
CHECK_AFTER=false
DRY_RUN=false
VERBOSE=false
LOCK_REPO=false
IS_REMOTE=false

# Process command line arguments if provided
if [ $# -ge 2 ]; then
    SOURCE_PATH="$1"
    DESTINATION="$2"
    shift 2

    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--check)
                CHECK_AFTER=true
                ;;
            -d|--dry-run)
                DRY_RUN=true
                ;;
            -v|--verbose)
                VERBOSE=true
                ;;
            -l|--lock)
                LOCK_REPO=true
                ;;
            *)
                print_message "warning" "Unknown option: $1"
                ;;
        esac
        shift
    done
fi

# If no source path provided, prompt for it
if [ -z "$SOURCE_PATH" ]; then
    print_message "info" "No source repository specified."
    read -p "Enter the path to your Borg repository: " SOURCE_PATH

    # Validate input
    if [ -z "$SOURCE_PATH" ]; then
        print_message "error" "No source repository provided. Exiting."
        exit 1
    fi
fi

# If no destination provided, prompt for it
if [ -z "$DESTINATION" ]; then
    print_message "info" "No destination specified."
    print_message "info" "For local transfer, enter a path like: /backup/path"
    print_message "info" "For remote transfer, enter: user@remote-pc:/backup/path"
    read -p "Enter destination: " DESTINATION

    # Validate input
    if [ -z "$DESTINATION" ]; then
        print_message "error" "No destination provided. Exiting."
        exit 1
    fi
fi

# If options not specified, interactively ask for them
if [ $# -lt 3 ]; then
    if ask_yes_no "Perform repository check after transfer?" "y"; then
        CHECK_AFTER=true
    fi

    if ask_yes_no "Lock repository during transfer (recommended)?" "y"; then
        LOCK_REPO=true
    fi

    if ask_yes_no "Run in dry-run mode first (recommended)?" "y"; then
        DRY_RUN=true
    fi

    if ask_yes_no "Enable verbose output?" "n"; then
        VERBOSE=true
    fi
fi

# Check if destination is remote
if [[ "$DESTINATION" == *":"* ]]; then
    IS_REMOTE=true
    REMOTE_HOST=${DESTINATION%%:*}
    REMOTE_PATH=${DESTINATION#*:}

    print_message "info" "Remote destination detected: $REMOTE_HOST"
fi

# Display transfer details for confirmation
echo ""
echo -e "${BLUE}Transfer Details:${NC}"
echo -e "Source: ${YELLOW}$SOURCE_PATH${NC}"
echo -e "Destination: ${YELLOW}$DESTINATION${NC}"
echo -e "Mode: ${YELLOW}$([ "$IS_REMOTE" = "true" ] && echo "Remote" || echo "Local")${NC}"
echo -e "Options:"
echo -e "  - Check after transfer: ${YELLOW}$([ "$CHECK_AFTER" = "true" ] && echo "Yes" || echo "No")${NC}"
echo -e "  - Dry run: ${YELLOW}$([ "$DRY_RUN" = "true" ] && echo "Yes" || echo "No")${NC}"
echo -e "  - Verbose output: ${YELLOW}$([ "$VERBOSE" = "true" ] && echo "Yes" || echo "No")${NC}"
echo -e "  - Lock repository: ${YELLOW}$([ "$LOCK_REPO" = "true" ] && echo "Yes" || echo "No")${NC}"
echo ""

# Confirm details before proceeding
if ! ask_yes_no "Does this look correct? Do you want to proceed?"; then
    print_message "info" "Operation cancelled by user."
    exit 0
fi

# Performing all the checks
print_message "info" "Running pre-transfer checks..."

# Verify Borg is installed locally
check_local_borg

# Check for and offer to install helper packages
install_helper_packages

# If remote, check remote connectivity and Borg installation
if [ "$IS_REMOTE" = "true" ]; then
    check_remote_borg "$REMOTE_HOST"
fi

# Verify source path is a valid Borg repository
if ! is_borg_repo "$SOURCE_PATH"; then
    if ask_yes_no "Source is not a valid Borg repository. Continue anyway?"; then
        print_message "warning" "Proceeding with an invalid source repository may cause problems."
    else
        print_message "info" "Operation cancelled by user."
        exit 1
    fi
fi

# Check for destination conflicts
if ! check_destination_conflict "$DESTINATION" "$IS_REMOTE"; then
    print_message "info" "Operation cancelled to prevent data loss."
    exit 1
fi

# Ensure destination directory exists
if ! ensure_directory_exists "$DESTINATION" "$IS_REMOTE"; then
    if ask_yes_no "Failed to create destination directory. Continue anyway?"; then
        print_message "warning" "Proceeding without proper destination directory may cause problems."
    else
        print_message "info" "Operation cancelled by user."
        exit 1
    fi
fi

# Check available disk space
check_disk_space "$SOURCE_PATH" "$DESTINATION" "$IS_REMOTE"

# Test transfer speed
check_transfer_speed "$DESTINATION" "$IS_REMOTE"

# Lock repository if requested
if [ "$LOCK_REPO" = "true" ]; then
    lock_repository "$SOURCE_PATH" "lock"
    # Set up trap to ensure repository is unlocked on exit
    trap 'print_message "info" "Unlocking repository before exit..."; lock_repository "$SOURCE_PATH" "unlock"' EXIT
fi

# Create rsync options
RSYNC_OPTS="-az --progress --checksum"
if [ "$DRY_RUN" = "true" ]; then
    RSYNC_OPTS="$RSYNC_OPTS --dry-run"
    print_message "info" "Running in DRY-RUN mode. No actual changes will be made."
fi
if [ "$VERBOSE" = "true" ]; then
    RSYNC_OPTS="$RSYNC_OPTS -v"
fi

# Run the transfer
print_message "info" "Starting transfer of Borg repository from '$SOURCE_PATH' to '$DESTINATION'"
print_message "info" "This may take a while depending on the repository size..."

TRANSFER_SUCCESS=false
VERIFICATION_SUCCESS=false
CHECK_SUCCESS=false

# Try transfer up to 3 times if verification fails
for attempt in {1..3}; do
    if [ $attempt -gt 1 ]; then
        print_message "info" "Retry attempt $attempt of 3..."
    fi

    # Run rsync
    if rsync $RSYNC_OPTS "$SOURCE_PATH/" "$DESTINATION/"; then
        print_message "success" "Transfer completed successfully."
        TRANSFER_SUCCESS=true
    else
        RSYNC_EXIT=$?
        print_message "error" "Transfer failed with exit code $RSYNC_EXIT"

        if ask_yes_no "Would you like to retry the transfer?"; then
            continue
        else
            TRANSFER_SUCCESS=false
            break
        fi
    fi

    # If we're in dry-run mode, don't bother with verification
    if [ "$DRY_RUN" = "true" ]; then
        print_message "info" "Skipping verification in dry-run mode."
        break
    fi

    # Verify transfer
    verify_result=$(verify_transfer "$SOURCE_PATH" "$DESTINATION" "$IS_REMOTE")
    if [ $? -eq 0 ]; then
        VERIFICATION_SUCCESS=true
        break
    elif [ $? -eq 2 ]; then
        # User requested retry
        continue
    else
        VERIFICATION_SUCCESS=false
        if ask_yes_no "Verification failed. Continue anyway?"; then
            print_message "warning" "Continuing with unverified transfer."
            break
        else
            print_message "info" "Operation cancelled by user."
            break
        fi
    fi
done

# Check repository integrity if requested and not in dry-run mode
if [ "$CHECK_AFTER" = "true" ] && [ "$DRY_RUN" = "false" ] && [ "$TRANSFER_SUCCESS" = "true" ]; then
    if [ "$IS_REMOTE" = "true" ]; then
        print_message "info" "Checking repository on remote host $REMOTE_HOST..."
        if ssh "$REMOTE_HOST" "command -v borg &> /dev/null && borg check \"$REMOTE_PATH\""; then
            print_message "success" "Repository check passed on remote host."
            CHECK_SUCCESS=true
            # Write success state to state file
            manage_state_file "write" "$SOURCE_PATH" "$DESTINATION"
        else
            print_message "warning" "Could not verify repository on remote host."
            print_message "info" "This could be because Borg is not installed there or the repository is damaged."

            if ask_yes_no "Would you like to try to install Borg on the remote host?"; then
                help_install_remote_borg "$REMOTE_HOST"
                # Try again after installation
                if ssh "$REMOTE_HOST" "command -v borg &> /dev/null && borg check \"$REMOTE_PATH\""; then
                    print_message "success" "Repository check passed on remote host."
                    CHECK_SUCCESS=true
                else
                    print_message "error" "Repository check failed even after installing Borg."
                    CHECK_SUCCESS=false
                fi
            else
                print_message "info" "Please verify the repository manually."
                CHECK_SUCCESS=false
            fi
        fi
    else
        # Local destination
        if check_repository "$DESTINATION"; then
            CHECK_SUCCESS=true
            # Write success state to state file
            manage_state_file "write" "$SOURCE_PATH" "$DESTINATION"
        else
            CHECK_SUCCESS=false
        fi
    fi
fi

# Display summary of operations
display_summary "$SOURCE_PATH" "$DESTINATION" "$TRANSFER_SUCCESS" "$VERIFICATION_SUCCESS" "$CHECK_SUCCESS"

# If this was a dry-run, ask if they want to do the real thing
if [ "$DRY_RUN" = "true" ] && [ "$TRANSFER_SUCCESS" = "true" ]; then
    if ask_yes_no "Dry run completed successfully. Would you like to perform the actual transfer now?"; then
        # Set dry-run to false and rerun the script with all the same parameters
        exec "$0" "$SOURCE_PATH" "$DESTINATION" $([ "$CHECK_AFTER" = "true" ] && echo "-c") $([ "$VERBOSE" = "true" ] && echo "-v") $([ "$LOCK_REPO" = "true" ] && echo "-l")
    else
        print_message "info" "Dry run completed. Exiting without performing actual transfer."
    fi
fi

print_message "info" "Script execution completed."
exit 0
