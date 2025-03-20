#!/bin/bash
# defaults.sh - Default configuration for Borg migration script
# Author: Haashim
# Date: March 20, 2025

# Default options
DEFAULT_CHECK_AFTER="false"  # Perform repository check after transfer
DEFAULT_DRY_RUN="false"      # Run in dry-run mode
DEFAULT_VERBOSE="false"      # Enable verbose output
DEFAULT_LOCK_REPO="false"    # Lock repository during transfer

# Transfer settings
MAX_TRANSFER_ATTEMPTS=3      # Maximum number of transfer retry attempts
TRANSFER_TEST_SIZE=10        # Size in MB for transfer speed test

# Colors for output
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m'           # No Color

# Script name for help text
SCRIPT_NAME="$(basename "$0")"

# Default temp directory for test files
TEMP_DIR="/tmp"

# State file location for tracking migrations
STATE_FILE="$HOME/.borg_migration_state.json"

# Optional packages to suggest installing
SUGGESTED_PACKAGES=("pv" "rsync")

# Remote setup options
SSH_TIMEOUT=5                # SSH connection timeout in seconds

# Verification settings
VERIFY_AFTER_TRANSFER="true" # Whether to verify after transfer