#!/bin/bash

# Password Character Finder
# This script lets you find characters at specific positions in a password
# It supports receiving passwords from:
#  - Piped input (e.g., from pass password manager)
#  - Command line argument
#  - Interactive prompt

# Display help information
show_help() {
  echo "Password Character Finder"
  echo "------------------------"
  echo "This script allows you to examine characters at specific positions in a password."
  echo "Positions start at 1 for the first character."
  echo ""
  echo "Usage:"
  echo "  ./password_finder.sh [password]            # Directly specify password"
  echo "  pass YourPasswordEntry | ./password_finder.sh  # Pipe from pass"
  echo "  ./password_finder.sh                       # Interactive prompt"
  echo ""
  echo "Example: If your password is 'Secure123', position 5 would be 'r'"
}

# Check if help was requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  show_help
  exit 0
fi

# Get the password using one of three methods:
# 1. Check if data is being piped in (from pass or another command)
if [ -t 0 ]; then
  # No pipe - stdin is a terminal
  
  # 2. Check for command line argument
  if [ $# -ge 1 ]; then
    password="$1"
  else
    # 3. No pipe, no argument - prompt for password
    read -s -p "Enter your password: " password
    echo ""  # Add a newline after password input
  fi
else
  # Data is being piped in - read the first line as password
  read password
  
  # Handle multi-line output from pass
  # We only want the first line which contains the password
fi

# Ensure password isn't empty
if [ -z "$password" ]; then
  echo "Error: Password cannot be empty."
  exit 1
fi

# Show password length for reference
echo "Password length: ${#password} characters"

# Main loop to keep checking positions
while true; do
  # Ask for the position - IMPORTANT: Read from /dev/tty to ensure we're reading from
  # the terminal even when stdin is receiving piped data
  read -p "Enter position to find (1-${#password}) or 'q' to quit: " input </dev/tty
  
  # Allow user to quit
  if [[ "$input" == "q" || "$input" == "quit" ]]; then
    echo "Exiting. Goodbye!"
    exit 0
  fi
  
  # Validate input is a number
  if ! [[ "$input" =~ ^[0-9]+$ ]]; then
    echo "Error: Please enter a valid number."
    continue
  fi
  
  position=$input
  
  # Check if position is within valid range
  if [ "$position" -lt 1 ] || [ "$position" -gt "${#password}" ]; then
    echo "Error: Position must be between 1 and ${#password}."
    continue
  fi
  
  # Get character at position (adjust for 0-based indexing)
  index=$((position-1))
  char="${password:$index:1}"
  
  # Show the result
  echo "Character at position $position: '$char'"
done
