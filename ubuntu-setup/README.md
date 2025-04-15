# Ubuntu System Setup - Modular Configuration Tool

## Overview

The Ubuntu System Setup is a modular, extensible tool designed to simplify and streamline the configuration of Ubuntu systems. By breaking system configuration into logical modules, it allows for better organization, easier maintenance, and flexible deployment options. Whether you're setting up a new server, configuring a desktop environment, or standardizing multiple systems, this tool provides a consistent and reliable approach.

## Key Features

- **Modular Architecture**: Each system function is isolated in its own module for better organization and maintainability
- **Interactive Interface**: User-friendly menu system for easy navigation
- **Idempotent Operations**: Scripts can be run multiple times safely without causing problems
- **Comprehensive Logging**: Detailed logs of all actions for troubleshooting and auditing
- **Configurability**: Extensive configuration options via the central config file
- **Flexibility**: Run individual modules or the complete setup process
- **Cross-Environment Support**: Works on both server and desktop Ubuntu installations
- **Shell Customization**: ZSH setup with Oh My Zsh, themes, and productivity-enhancing plugins

## Directory Structure

```
ubuntu-setup/
├── modules/                 # Directory containing all modules
│   ├── utils.sh             # Utility functions used across modules
│   ├── user_management.sh   # User creation and management  
│   ├── ssh_setup.sh         # SSH server installation and configuration
│   ├── desktop_env.sh       # Desktop environment installation
│   ├── remote_access.sh     # xRDP and remote access configuration
│   ├── backup_tools.sh      # BorgBackup and Vorta installation
│   ├── system_update.sh     # System update and package management
│   ├── zsh_setup.sh         # ZSH shell installation and configuration
│   └── samba_setup.sh       # Samba server installation and configuration
├── config/                  # Configuration files
│   └── setup.conf           # Default configuration settings
```

## Installation

### Manual Installation

You can set up the structure manually:

1. Create the directory structure:
    

```bash
    `mkdir -p ubuntu-setup/modules ubuntu-setup/config`
```

2. Download the main script and modules:
    

```bash
# Download main script
wget -O ubuntu-setup/ubuntu-setup.sh https://example.com/ubuntu-setup.sh
chmod +x ubuntu-setup/ubuntu-setup.sh

# Download modules
wget -O ubuntu-setup/modules/utils.sh https://example.com/modules/utils.sh
wget -O ubuntu-setup/modules/user_management.sh https://example.com/modules/user_management.sh
# ... download remaining modules

# Download configuration
wget -O ubuntu-setup/config/setup.conf https://example.com/config/setup.conf
```

3. Make all scripts executable:
    

```bash
    chmod +x ubuntu-setup/modules/*.sh
```

## Getting Started

### Running the Full Setup

To run the complete setup with interactive prompts:

```bash
cd ubuntu-setup 
sudo ./ubuntu-setup.sh
```

This will present you with a menu of options to configure your system.

### Running Individual Modules

To run a specific module only:

```bash
cd ubuntu-setup
sudo ./ubuntu-setup.sh --module=module_name
```

For example, to only set up SSH:

```bash
sudo ./ubuntu-setup.sh --module=ssh_setup
```

Or to set up ZSH shell with Oh My Zsh:

```bash
sudo ./ubuntu-setup.sh --module=zsh_setup
```

### Non-Interactive Mode

For automated deployments, you can run in non-interactive mode:

```bash
sudo ./ubuntu-setup.sh --non-interactive --config=/path/to/custom-config.conf
```

## Configuration

The system is highly configurable through the `setup.conf` file located in the `config` directory. This file contains default settings for all modules. You can customize these settings to match your requirements.

### Key Configuration Sections

- **General Settings**: Log file location, build directories, etc.
- **User Management**: Default user settings, groups, shell
- **SSH Configuration**: SSH server settings, authentication methods
- **Backup Configuration**: BorgBackup settings, schedules, retention policies
- **Desktop Environment**: Default desktop, themes, applications
- **Remote Access**: xRDP, VNC, and firewall settings
- **System Updates**: Automatic updates, scheduling, notifications
- **Common Utilities**: Default packages to install
- **ZSH Configuration**: Theme, plugins, and aliases

### Custom Configuration Files

You can create custom configuration files for different deployment scenarios:

```bash
cp ubuntu-setup/config/setup.conf ubuntu-setup/config/server-setup.conf
# Edit server-setup.conf for server-specific settings

# Then use it:
sudo ./ubuntu-setup.sh --config=config/server-setup.conf
```

## Module System

### Core Modules

- **utils.sh**: Contains utility functions used by all other modules
- **user_management.sh**: Creates and configures users, sets up SSH keys
- **ssh_setup.sh**: Installs and configures the SSH server
- **desktop_env.sh**: Installs and configures desktop environments
- **remote_access.sh**: Sets up xRDP and VNC for remote desktop access
- **backup_tools.sh**: Installs and configures BorgBackup and Vorta
- **system_update.sh**: Handles system updates and package management
- **zsh_setup.sh**: Installs and configures ZSH with Oh My Zsh and plugins
- **samba_setup.sh**: Installs and configures the Samba server for file sharing

### How Modules Work

Each module follows a consistent pattern:

1. Module files must be sourced, not executed directly
2. Each module provides one or more functions that can be called by the main script
3. The main function typically has the same name as the module (without the .sh extension)
4. Functions use utility functions from utils.sh for consistent behavior
5. Each function returns 0 on success and non-zero on failure

### Creating Custom Modules

You can create your own modules to extend the system:

1. Create a new .sh file in the modules directory:
    

```bash
touch ubuntu-setup/modules/my_custom_module.sh
chmod +x ubuntu-setup/modules/my_custom_module.sh
```

2. Use this template:
    

```bash
#!/bin/bash
# my_custom_module.sh - Description of your module
# This module handles...

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    exit 1
fi

# Main function for this module
my_custom_module() {
    print_section_header "My Custom Module"
    
    # Your code here
    echo "Performing custom operations..."
    
    # Example: Install a package
    if ! is_package_installed "mypackage"; then
        apt install -y mypackage
        check_status "Installed mypackage" || return 1
    else
        echo -e "${GREEN}mypackage is already installed.${NC}" | tee -a "$LOG_FILE"
    fi
    
    return 0
}

# Additional helper functions as needed
```

3. Update the main script to recognize your module (optional)

## Advanced Usage

### Command Line Options

The main script supports several command-line options:

- `--help`: Display usage information
- `--non-interactive`: Run without user prompts, using defaults
- `--config=file`: Use a specific configuration file
- `--module=name`: Run only the specified module
- `--list-modules`: List all available modules
- `--verbose`: Enable verbose output
- `--create-module-stubs`: Create empty module stubs

### Logging

All operations are logged to `/var/log/ubuntu-setup.log` by default. You can change this location in the configuration file.

To view logs in real-time during execution:

bash

Copy

```bash
sudo tail -f /var/log/ubuntu-setup.log
```

### Error Handling

The system includes robust error handling:

- Each operation is checked for success
- Errors are displayed and logged
- Failed operations return non-zero exit codes
- The script can continue despite some failures

## Real-World Examples

### Server Setup Example

To set up a minimal Ubuntu server with SSH and automatic updates:

```bash
sudo ./ubuntu-setup.sh --module=ssh_setup
sudo ./ubuntu-setup.sh --module=system_update --non-interactive
sudo ./ubuntu-setup.sh --module=zsh_setup
```

### Desktop Setup Example

To set up a complete Ubuntu desktop with remote access:

```bash
sudo ./ubuntu-setup.sh
# Then select options 2 (Desktop Environment), 3 (Remote Access), and 4 (User Management) > 3 (Setup ZSH Shell) from the menu
```

### Automation Example

To automate deployment across multiple systems:

1. Create a custom configuration file:
    

```bash
cp config/setup.conf config/automated.conf
# Edit automated.conf with your settings
```

2. Create a deployment script:
    

```bash
#!/bin/bash
cd /path/to/ubuntu-setup
sudo ./ubuntu-setup.sh --non-interactive --config=config/automated.conf
```

## Troubleshooting

### Common Issues

1. **Permission denied errors**:
    - Ensure you're running with sudo privileges
    - Check file permissions on scripts (should be executable)
2. **Module not found errors**:
    - Verify that all module files exist in the modules directory
    - Check for typos in module names when using --module option
3. **Configuration errors**:
    - Validate your configuration file syntax
    - Check for missing or invalid settings

### Debug Mode

To run in debug mode with detailed output:

```bash
sudo bash -x ./ubuntu-setup.sh
```

## Contributing

To contribute to this project:

1. Create new modules or enhance existing ones
2. Ensure your code follows the established patterns
3. Test thoroughly on different Ubuntu versions
4. Document your changes in the module headers

## Conclusion

The modular Ubuntu System Setup tool provides a flexible, maintainable approach to system configuration. By separating functionality into logical modules, it simplifies both the development and usage of system configuration scripts. Whether you're setting up a single system or managing a fleet of servers, this tool can help streamline your Ubuntu deployments.
