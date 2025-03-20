# Borg Migration Tool

A modular, interactive tool for safely migrating Borg backup repositories between systems.

## Features

- Safe transfer of Borg repositories with validation
- Support for both local and remote transfers
- Comprehensive pre-transfer checks
- Repository verification and integrity checking
- Dry-run mode for testing before actual transfer
- Interactive prompts for ease of use
- Progress visualization during transfer
- Detailed summary and next steps

## Requirements

- Borg Backup (installed on the source system)
- rsync
- SSH (for remote transfers)
- Optional: pv (for better progress visualization)

## Installation

1. Clone this repository:
    
    ```
    git clone https://github.com/your-username/borg-migration.git
    cd borg-migration
    ```
    
2. Make the main script executable:
    
    ```
    chmod +x borg-migrate.sh
    ```
    

## Usage

### Basic Usage

```
./borg-migrate.sh [source_path] [destination] [options]
```

If you run the script without arguments, it will prompt you interactively for all required information.

### Examples

1. Local transfer with repository check after transfer:
    
    ```
    ./borg-migrate.sh /path/to/source/repo /path/to/destination/repo -c
    ```
    
2. Remote transfer with dry-run:
    
    ```
    ./borg-migrate.sh /path/to/source/repo user@remote-server:/path/to/destination -d
    ```
    
3. Full options with repository locking:
    
    ```
    ./borg-migrate.sh /path/to/source/repo user@remote-server:/path/to/destination -c -l -v
    ```
    

### Options

- `-c, --check` Perform repository check after transfer
- `-d, --dry-run` Show what would be transferred without actually transferring
- `-v, --verbose` Enable verbose output
- `-l, --lock` Lock repository during transfer (prevents corruption)
- `-h, --help` Display help message

## Modular Structure

The script is organized into modules for better maintainability:

```
borg-migration/
├── borg-migrate.sh          # Main script
├── config/
│   └── defaults.sh          # Default configuration
├── lib/
│   ├── common.sh            # Common utilities
│   ├── setup.sh             # Setup and validation functions
│   ├── repository.sh        # Repository management functions
│   ├── filesystem.sh        # Directory and space management
│   ├── transfer.sh          # Transfer-related functions
│   └── output.sh            # Output and summary functions
└── README.md                # Documentation
```

## Customization

You can customize default behavior by editing `config/defaults.sh`.

## Safety Features

- Validation of source and destination
- Disk space checks
- Transfer verification
- Dry-run mode for testing
- Confirmation prompts for potentially dangerous operations
- Repository integrity checking
