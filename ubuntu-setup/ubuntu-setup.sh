#!/bin/bash
# ubuntu-setup.sh - Main script for Ubuntu system setup
# This script coordinates the modular components of the system setup

# Script variables
SCRIPT_PATH=$(realpath "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_DIR="$SCRIPT_DIR/config"
export MAIN_SCRIPT="$SCRIPT_PATH"

# Create modules directory if it doesn't exist
if [ ! -d "$MODULES_DIR" ]; then
    echo "Creating modules directory: $MODULES_DIR"
    mkdir -p "$MODULES_DIR"
fi

# Create config directory if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Creating config directory: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
fi

# Function to display usage information
display_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Ubuntu System Setup - A modular system configuration tool"
    echo ""
    echo "Options:"
    echo "  --help                  Display this help message"
    echo "  --non-interactive       Run in non-interactive mode using default settings"
    echo "  --config=<config_file>  Use specified configuration file"
    echo "  --module=<module_name>  Run only the specified module"
    echo "  --list-modules          List available modules"
    echo "  --verbose               Enable verbose output"
    echo "  --create-module-stubs   Create empty module stubs in the modules directory"
    echo ""
    echo "Examples:"
    echo "  $0                      Run the interactive setup wizard"
    echo "  $0 --module=desktop_env Run only the desktop environment module"
    echo "  $0 --list-modules       List all available modules"
}

# Function to check if all required modules are present
check_modules() {
    local required_modules=(
        "utils.sh"
        "user_management.sh"
        "ssh_setup.sh"
        "desktop_env.sh"
        "remote_access.sh"
        "backup_tools.sh"
        "system_update.sh"
        "zsh_setup.sh"
        "samba_setup.sh" # Added Samba module
    )

    local missing_modules=()

    for module in "${required_modules[@]}"; do
        if [ ! -f "$MODULES_DIR/$module" ]; then
            missing_modules+=("$module")
        fi
    done

    if [ ${#missing_modules[@]} -gt 0 ]; then
        echo "WARNING: The following modules are missing:"
        for missing in "${missing_modules[@]}"; do
            echo "  - $missing"
        done

        echo ""
        echo "Would you like to create these module stubs? (y/n)"
        read -r create_stubs

        if [[ "$create_stubs" == "y" || "$create_stubs" == "Y" ]]; then
            create_module_stubs "${missing_modules[@]}"
        else
            echo "Cannot continue without required modules. Please create the missing modules and try again."
            exit 1
        fi
    fi
}

# Function to create module stubs
create_module_stubs() {
    local modules=("$@")

    echo "Creating module stubs..."

    for module in "${modules[@]}"; do
        local module_name="${module%.sh}"
        local module_title="${module_name//_/ }"

        echo "Creating stub for $module..."

        cat > "$MODULES_DIR/$module" << EOF
#!/bin/bash
# $module - ${module_title^} functions
# This module handles ${module_title} related operations

# Ensure this script is sourced, not executed
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Function to demonstrate ${module_title}
${module_name}() {
    print_section_header "${module_title^}"
    echo "This is a stub function for ${module_title}. Please implement me!"
    return 0
}
EOF
        chmod +x "$MODULES_DIR/$module"
        echo "Created stub for $module at $MODULES_DIR/$module"
    done

    echo "Module stubs created. Please edit them to implement their functionality."
}

# Function to source modules
source_modules() {
    # First, source the utils module as it's required by all other modules
    if [ -f "$MODULES_DIR/utils.sh" ]; then
        source "$MODULES_DIR/utils.sh"
    else
        echo "Error: utils.sh module not found! This is a required module."
        exit 1
    fi

    # Source all other modules
    for module in "$MODULES_DIR"/*.sh; do
        # Skip utils.sh as we've already sourced it
        if [ "$(basename "$module")" != "utils.sh" ]; then
            source "$module"
        fi
    done
}

# Function to list available modules
list_modules() {
    echo "Available modules:"

    if [ ! -d "$MODULES_DIR" ] || [ -z "$(ls -A "$MODULES_DIR")" ]; then
        echo "  No modules found in $MODULES_DIR"
        return
    fi

    for module in "$MODULES_DIR"/*.sh; do
        # Get the module name and description
        local module_name=$(basename "$module" .sh)
        local module_desc=$(grep -m 1 "# $module_name.sh -" "$module" 2>/dev/null | sed "s/# $module_name.sh - //")

        if [ -z "$module_desc" ]; then
            module_desc="No description available"
        fi

        echo "  $module_name - $module_desc"
    done
}

# Function to run setup wizard
run_setup_wizard() {
    # Check if running with sudo privileges
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run with sudo privileges."
        echo "Please run: sudo bash $0"
        exit 1
    fi

    # Source utility functions
    source "$MODULES_DIR/utils.sh"

    # Initialize logging
    init_logging

    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     UBUNTU SYSTEM SETUP & CONFIGURATION     ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"

    # Get Ubuntu version and desktop environment info
    ubuntu_version=$(get_ubuntu_version)

    echo -e "\n${BLUE}=== Ubuntu System Information ===${NC}"
    echo -e "Ubuntu Version: ${YELLOW}$ubuntu_version${NC}"

    # Check if running on a desktop system
    if is_desktop_installed; then
        is_desktop=true
        echo -e "Desktop Environment: ${YELLOW}$(detect_desktop_environment)${NC}"
    else
        is_desktop=false
        echo -e "Desktop Environment: ${YELLOW}Not installed${NC}"
    fi
    echo ""

    # Main menu
    while true; do
        echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║               SETUP OPTIONS                 ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
        echo "1. System Updates and Package Management"
        echo "2. Install/Configure Desktop Environment"
        echo "3. Remote Access Setup (SSH, xRDP, VNC)"
        echo "4. User Management"
        echo "5. Backup Tools (BorgBackup, Vorta)"
        echo "6. Samba Server Setup" # Added Samba option
        echo "7. Maintenance and Utilities" # Shifted option
        echo "8. Run Full Setup (Recommended for new systems)" # Shifted option
        echo "9. Exit" # Shifted option

        echo -n "Enter your choice (1-9): " # Updated range
        read -r choice

        case $choice in
            1)
                # System Updates submenu
                echo -e "${BLUE}=== System Updates and Package Management ===${NC}"
                echo "1. Update System Packages"
                echo "2. Configure Automatic Updates"
                echo "3. Install Common Utilities"
                echo "4. Clean System"
                echo "5. Back to Main Menu"

                echo -n "Enter your choice (1-5): "
                read -r update_choice

                case $update_choice in
                    1) update_system ;;
                    2) configure_automatic_updates ;;
                    3) install_common_utilities ;;
                    4) clean_system ;;
                    5) continue ;;
                    *) echo -e "${RED}Invalid choice${NC}" ;;
                esac
                ;;

            2)
                # Desktop Environment submenu
                echo -e "${BLUE}=== Desktop Environment ===${NC}"
                if ! $is_desktop; then
                    if ask_yes_no "No desktop environment detected. Would you like to install one?"; then
                        install_desktop_environment
                        is_desktop=true
                    fi
                else
                    echo "1. Install Different Desktop Environment"
                    echo "2. Configure Desktop Settings"
                    echo "3. Back to Main Menu"

                    echo -n "Enter your choice (1-3): "
                    read -r desktop_choice

                    case $desktop_choice in
                        1) install_desktop_environment ;;
                        2) configure_desktop_settings ;;
                        3) continue ;;
                        *) echo -e "${RED}Invalid choice${NC}" ;;
                    esac
                fi
                ;;

            3)
                # Remote Access submenu
                echo -e "${BLUE}=== Remote Access Setup ===${NC}"
                echo "1. Setup SSH Server"
                echo "2. Configure SSH Security"
                echo "3. Setup xRDP (Windows Remote Desktop)"
                echo "4. Setup VNC Server"
                echo "5. Back to Main Menu"

                echo -n "Enter your choice (1-5): "
                read -r remote_choice

                case $remote_choice in
                    1) setup_ssh_server ;;
                    2) configure_ssh_security ;;
                    3) setup_xrdp ;;
                    4) setup_vnc_server ;;
                    5) continue ;;
                    *) echo -e "${RED}Invalid choice${NC}" ;;
                esac
                ;;

            4)
                # User Management submenu
                echo -e "${BLUE}=== User Management ===${NC}"
                echo "1. Create New User"
                echo "2. Setup SSH Key for Current User"
                echo "3. Setup ZSH Shell"
                echo "4. Back to Main Menu"

                echo -n "Enter your choice (1-3): "
                read -r user_choice

                case $user_choice in
                    1) create_new_user ;;
                    2) setup_current_user_ssh ;;
                    3) zsh_setup ;;
                    4) continue ;;
                    *) echo -e "${RED}Invalid choice${NC}" ;;
                esac
                ;;

            5)
                # Backup Tools submenu
                echo -e "${BLUE}=== Backup Tools ===${NC}"
                echo "1. Install BorgBackup"
                if $is_desktop; then
                    echo "2. Install Vorta (GUI for BorgBackup)"
                fi
                echo "3. Configure BorgBackup Defaults"
                echo "4. Setup Automated Backups"
                echo "5. Back to Main Menu"

                echo -n "Enter your choice (1-5): "
                read -r backup_choice

                case $backup_choice in
                    1) install_borg_backup ;;
                    2)
                        if $is_desktop; then
                            install_vorta_from_source
                        else
                            echo -e "${RED}No desktop environment detected. Cannot install Vorta.${NC}"
                        fi
                        ;;
                    3) configure_borg_defaults ;;
                    4) configure_backup_scheduling ;;
                    5) continue ;;
                    *) echo -e "${RED}Invalid choice${NC}" ;;
                esac
                ;;

            6)
                # Samba Setup
                samba_setup
                ;;

            7) # Shifted from 6
                # Maintenance submenu
                echo -e "${BLUE}=== Maintenance and Utilities ===${NC}"
                echo "1. Clean System"
                echo "2. View System Logs"
                echo "3. Back to Main Menu"

                echo -n "Enter your choice (1-3): "
                read -r maint_choice

                case $maint_choice in
                    1) clean_system ;;
                    2)
                        echo -e "${YELLOW}Last 50 lines of system log:${NC}"
                        tail -n 50 /var/log/syslog
                        echo ""
                        echo -e "${YELLOW}Press Enter to continue...${NC}"
                        read -r
                        ;;
                    3) continue ;;
                    *) echo -e "${RED}Invalid choice${NC}" ;;
                esac
                ;;

            8) # Shifted from 7
                # Full Setup
                print_section_header "Running Full System Setup"

                # Update system first
                update_system

                # Install desktop environment if not present
                if ! $is_desktop; then
                    if ask_yes_no "Would you like to install a desktop environment?"; then
                        install_desktop_environment
                        is_desktop=true
                    fi
                fi

                # Set up SSH server
                if ask_yes_no "Would you like to set up the SSH server?"; then
                    setup_ssh_server
                fi

                # Set up remote desktop
                if $is_desktop; then
                    if ask_yes_no "Would you like to set up xRDP for Windows Remote Desktop connections?"; then
                        setup_xrdp
                    fi
                fi

                # Create new user if requested
                if ask_yes_no "Would you like to set up a new user?"; then
                    create_new_user
                fi

                # Set up SSH key for current user
                setup_current_user_ssh

                # Set up ZSH if requested
                if ask_yes_no "Would you like to set up ZSH shell with Oh My Zsh?"; then
                    zsh_setup
                fi

                # Install BorgBackup
                if ask_yes_no "Would you like to install BorgBackup for backups?"; then
                    install_borg_backup

                    # Install Vorta if desktop environment is available
                    if $is_desktop; then
                        if ask_yes_no "Would you like to install Vorta (GUI frontend for BorgBackup)?"; then
                            install_vorta_from_source
                        fi
                    fi

                    # Configure BorgBackup
                    if ask_yes_no "Would you like to configure BorgBackup defaults?"; then
                        configure_borg_defaults

                        # Set up automated backups
                        if ask_yes_no "Would you like to set up automated backups?"; then
                            configure_backup_scheduling
                        fi
                    fi
                fi

                # Configure automatic updates
                if ask_yes_no "Would you like to configure automatic system updates?"; then
                    configure_automatic_updates
                fi

                # Install common utilities
                if ask_yes_no "Would you like to install common utilities?"; then
                    install_common_utilities
                fi

                echo -e "${GREEN}Full system setup complete!${NC}"
                ;;

            9) # Shifted from 8
                # Exit
                echo -e "${GREEN}Thank you for using the Ubuntu System Setup script.${NC}"
                echo -e "Log file available at: ${YELLOW}$LOG_FILE${NC}"
                exit 0
                ;;

            *)
                echo -e "${RED}Invalid choice. Please enter a number between 1 and 9.${NC}" # Updated range
                ;;
        esac
    done
}

# Function to run a specific module
run_module() {
    local module_name="$1"
    local module_file="$MODULES_DIR/${module_name}.sh"

    if [ ! -f "$module_file" ]; then
        echo "Error: Module '$module_name' not found."
        list_modules
        exit 1
    fi

    # Check if running with sudo privileges
    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run with sudo privileges."
        echo "Please run: sudo bash $0 --module=$module_name"
        exit 1
    fi

    # Source utils module first
    source "$MODULES_DIR/utils.sh"

    # Then source the requested module
    source "$module_file"

    # Initialize logging
    init_logging

    echo "Running module: $module_name"

    # Call the function with the same name as the module
    if declare -f "$module_name" > /dev/null; then
        $module_name
    else
        echo "Error: Function '$module_name' not found in module."
        exit 1
    fi
}

# Parse command line arguments
INTERACTIVE=true
MODULE_TO_RUN=""
CONFIG_FILE=""
VERBOSE=false
CREATE_STUBS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            display_usage
            exit 0
            ;;
        --non-interactive)
            INTERACTIVE=false
            shift
            ;;
        --config=*)
            CONFIG_FILE="${1#*=}"
            shift
            ;;
        --module=*)
            MODULE_TO_RUN="${1#*=}"
            shift
            ;;
        --list-modules)
            list_modules
            exit 0
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --create-module-stubs)
            CREATE_STUBS=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            display_usage
            exit 1
            ;;
    esac
done

# Create module stubs if requested
if [ "$CREATE_STUBS" = true ]; then
    required_modules=(
        "utils.sh"
        "user_management.sh"
        "ssh_setup.sh"
        "desktop_env.sh"
        "remote_access.sh"
        "backup_tools.sh"
        "system_update.sh"
        "zsh_setup.sh" # Added zsh_setup.sh here too
        "samba_setup.sh" # Added samba_setup.sh here
    )
    create_module_stubs "${required_modules[@]}"
    exit 0
fi

# Check if required modules exist
check_modules

# Execute based on arguments
if [ -n "$MODULE_TO_RUN" ]; then
    # Source specific module and run it
    run_module "$MODULE_TO_RUN"
else
    # Source all modules and run the wizard
    source_modules
    run_setup_wizard
fi

exit 0
