#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error when substituting.
# Prevent errors in a pipeline from being masked.
set -euo pipefail

# --- Configuration ---
# Default subdirectory within the password store
DEFAULT_SUBDIR="ToMove"
# Default password length
DEFAULT_PW_LENGTH=22
# List of predefined email addresses
emails=(
    "haashimalvi@pm.me"
    "haashimalvi@protonmail.com"
    "haashimalvi@hotmail.com"
    "haashim97@gmail.com"
    "h.alvi@edu.salford.ac.uk"
)

# --- Variables ---
Title=""
URL=""
Username=""
Password=""
# Store initial defaults to check if flags were used
INITIAL_DEFAULT_PW_LENGTH="$DEFAULT_PW_LENGTH"
INITIAL_DEFAULT_MIN_UPPER=1
INITIAL_DEFAULT_MIN_LOWER=1
INITIAL_DEFAULT_MIN_DIGITS=1
INITIAL_DEFAULT_MIN_SYMBOLS=1
INITIAL_DEFAULT_CUSTOM_SYMBOLS='~!@#$%^&*()_+-=[]{}|;:,.<>/?'
# Working variables, potentially updated by flags
PasswordLength="$INITIAL_DEFAULT_PW_LENGTH"
MinUppercase="$INITIAL_DEFAULT_MIN_UPPER"
MinLowercase="$INITIAL_DEFAULT_MIN_LOWER"
MinDigits="$INITIAL_DEFAULT_MIN_DIGITS"
MinSymbols="$INITIAL_DEFAULT_MIN_SYMBOLS"
CustomSymbols="$INITIAL_DEFAULT_CUSTOM_SYMBOLS"
Subdirectory="${PWGEN_SUBDIR:-$DEFAULT_SUBDIR}" # Use env var if set, else default
CamelCaseTitle=false
email=""

# --- Functions ---

# Print error message and exit
error_exit() {
    printf "Error: %s\n" "$1" >&2
    exit 1
}

# Print usage information
usage() {
    printf "Usage: %s [options]\n" "$(basename "$0")"
    printf "Options:\n"
    printf "  -t TITLE      Specify the title (entry name)\n"
    printf "  -u URL        Specify the URL\n"
    printf "  -U USERNAME   Specify the username\n"
    printf "  -p PASSWORD   Specify the password (prompts if not provided)\n"
    printf "  -l LENGTH     Specify password length (default: %s)\n" "$DEFAULT_PW_LENGTH"
    printf "  -u MIN_UPPER  Minimum uppercase characters (default: %s)\n" "$MinUppercase"
    printf "  -w MIN_LOWER  Minimum lowercase characters (default: %s)\n" "$MinLowercase"
    printf "  -d MIN_DIGITS Minimum digits (default: %s)\n" "$MinDigits"
    printf "  -s MIN_SYMB   Minimum symbols (default: %s)\n" "$MinSymbols"
    printf "  -S SYMBOLS    Custom set of symbols to use (default: '%s')\n" "$CustomSymbols"
    printf "  -D SUBDIR     Specify subdirectory in password store (default: %s or PWGEN_SUBDIR env var)\n" "$DEFAULT_SUBDIR" # Changed -d to -D to avoid conflict
    printf "  -c            Enable CamelCase for the title (default: disabled)\n"
    printf "  -h            Display this help message\n"
    exit 0
}

# Convert a string to camel case
# Example: "some title" -> "SomeTitle"
to_camel_case() {
    printf "%s" "$1" | awk -F'[[:space:]_-]+' '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1' OFS=""
}

# Generate a password meeting specific requirements
# Args: $1=length, $2=min_upper, $3=min_lower, $4=min_digits, $5=min_symbols, $6=symbol_set
generate_password_with_reqs() {
    local length="$1"
    local min_upper="$2"
    local min_lower="$3"
    local min_digits="$4"
    local min_symbols="$5"
    local symbol_set="$6"

    local upper_chars='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local lower_chars='abcdefghijklmnopqrstuvwxyz'
    local digit_chars='0123456789'

    local required_chars=""
    local all_chars=""
    local remaining_length="$length"
    local password=""

    # Add required uppercase
    if [[ "$min_upper" -gt 0 ]]; then
        required_chars+=$(LC_ALL=C tr -dc "$upper_chars" < /dev/urandom | head -c "$min_upper")
        all_chars+="$upper_chars"
        remaining_length=$((remaining_length - min_upper))
    fi

    # Add required lowercase
    if [[ "$min_lower" -gt 0 ]]; then
        required_chars+=$(LC_ALL=C tr -dc "$lower_chars" < /dev/urandom | head -c "$min_lower")
        all_chars+="$lower_chars"
        remaining_length=$((remaining_length - min_lower))
    fi

    # Add required digits
    if [[ "$min_digits" -gt 0 ]]; then
        required_chars+=$(LC_ALL=C tr -dc "$digit_chars" < /dev/urandom | head -c "$min_digits")
        all_chars+="$digit_chars"
        remaining_length=$((remaining_length - min_digits))
    fi

    # Add required symbols
    if [[ "$min_symbols" -gt 0 ]]; then
        if [[ -z "$symbol_set" ]]; then
            error_exit "Symbol set cannot be empty when minimum symbols > 0."
        fi
        required_chars+=$(LC_ALL=C tr -dc "$symbol_set" < /dev/urandom | head -c "$min_symbols")
        all_chars+="$symbol_set"
        remaining_length=$((remaining_length - min_symbols))
    fi

    # Ensure we have a character set for remaining chars if all minimums were 0
    if [[ -z "$all_chars" ]]; then
       all_chars="${upper_chars}${lower_chars}${digit_chars}${symbol_set}"
       if [[ -z "$all_chars" ]]; then
           error_exit "Cannot generate password with no allowed character types."
       fi
    fi


    # Check if minimum requirements exceed length
    if [[ "$remaining_length" -lt 0 ]]; then
        error_exit "Minimum character requirements ($((length - remaining_length))) exceed requested password length ($length)."
    fi

    # Add remaining random characters from the combined set
    local remaining_chars=""
    if [[ "$remaining_length" -gt 0 ]]; then
       remaining_chars=$(LC_ALL=C tr -dc "$all_chars" < /dev/urandom | head -c "$remaining_length")
    fi

    # Combine required and remaining characters, then shuffle
    password=$(printf "%s%s" "$required_chars" "$remaining_chars" | fold -w1 | shuf | tr -d '\n')

    printf "%s" "$password"
}


# Prompt for input with validation for non-empty required fields
prompt_required() {
    local prompt_msg="$1"
    local var_name="$2"
    local input=""
    while [[ -z "$input" ]]; do
        read -p "$prompt_msg" input
        if [[ -z "$input" ]]; then
            printf "This field is required. Please enter a value.\n"
        fi
    done
    printf -v "$var_name" "%s" "$input"
}

# Prompt for numeric input with validation
prompt_numeric() {
    local prompt_msg="$1"
    local var_name="$2"
    local default_value="${3:-}"
    local input=""
    while true; do
        read -p "$prompt_msg" input
        input="${input:-$default_value}" # Apply default if input is empty
        if [[ "$input" =~ ^[0-9]+$ ]]; then
            printf -v "$var_name" "%s" "$input"
            break
        else
            printf "Invalid input. Please enter a number.\n"
        fi
    done
}

# --- Argument Parsing ---
# Use getopt for robust argument parsing (Note: -d changed to -D)
options=$(getopt -o t:u:U:p:l:u:w:d:s:S:D:ch --long title:,url:,username:,password:,length:,min-upper:,min-lower:,min-digits:,min-symbols:,symbols:,subdir:,camelcase,help -- "$@")
# Check for getopt errors
if [[ $? -ne 0 ]]; then
    usage # Will exit
fi

eval set -- "$options"

while true; do
    case "$1" in
        -t|--title) Title="$2"; shift 2 ;;
        -u|--url) URL="$2"; shift 2 ;;
        -U|--username) Username="$2"; shift 2 ;;
        -p|--password) Password="$2"; shift 2 ;;
        -l|--length) PasswordLength="$2"; shift 2 ;; # Validate later
        -u|--min-upper) MinUppercase="$2"; shift 2 ;; # Validate later
        -w|--min-lower) MinLowercase="$2"; shift 2 ;; # Validate later
        -d|--min-digits) MinDigits="$2"; shift 2 ;; # Validate later
        -s|--min-symbols) MinSymbols="$2"; shift 2 ;; # Validate later
        -S|--symbols) CustomSymbols="$2"; shift 2 ;;
        -D|--subdir) Subdirectory="$2"; shift 2 ;; # Changed from -d
        -c|--camelcase) CamelCaseTitle=true; shift ;;
        -h|--help) usage ;; # Will exit
        --) shift; break ;;
        *) error_exit "Internal error parsing options!" ;;
    esac
done

# --- Validate Numeric Arguments ---
if ! [[ "$PasswordLength" =~ ^[0-9]+$ ]] || [[ "$PasswordLength" -eq 0 ]]; then error_exit "Invalid password length specified: '$PasswordLength'. Must be a positive integer."; fi
if ! [[ "$MinUppercase" =~ ^[0-9]+$ ]]; then error_exit "Invalid minimum uppercase count: '$MinUppercase'. Must be an integer."; fi
if ! [[ "$MinLowercase" =~ ^[0-9]+$ ]]; then error_exit "Invalid minimum lowercase count: '$MinLowercase'. Must be an integer."; fi
if ! [[ "$MinDigits" =~ ^[0-9]+$ ]]; then error_exit "Invalid minimum digit count: '$MinDigits'. Must be an integer."; fi
if ! [[ "$MinSymbols" =~ ^[0-9]+$ ]]; then error_exit "Invalid minimum symbol count: '$MinSymbols'. Must be an integer."; fi


# --- Pre-checks ---

# Check if pass command exists
if ! command -v pass &> /dev/null; then
    error_exit "'pass' command not found. Please install password-store."
fi

# Check if the password store directory exists
PASSWORD_STORE_ROOT="$HOME/.password-store"
if [ ! -d "$PASSWORD_STORE_ROOT" ]; then
    error_exit "Password store directory ($PASSWORD_STORE_ROOT) does not exist. Please initialize your password store first (pass init <gpg-id>)."
fi

# Ensure the target subdirectory exists
PASSWORD_STORE_SUBDIR="$PASSWORD_STORE_ROOT/$Subdirectory"
mkdir -p "$PASSWORD_STORE_SUBDIR"

# --- Interactive Prompts (if needed) ---

# Prompt for Title if not provided via args
if [[ -z "$Title" ]]; then
    prompt_required "Enter the Title (this will be the name of the entry) [required]: " Title
fi

# Prompt for URL if not provided via args
if [[ -z "$URL" ]]; then
    read -p "Enter the URL (leave empty if not applicable): " URL
fi

# Prompt for Username if not provided via args
if [[ -z "$Username" ]]; then
    read -p "Enter the Username (leave empty to potentially use email): " Username_input
    Username="$Username_input" # Assign to Username variable
fi

# Email selection (always interactive for now)
printf "Select an email address (leave blank if not applicable):\n"
for i in "${!emails[@]}"; do
    printf "%d) %s\n" "$((i+1))" "${emails[$i]}"
done
printf "Enter the number corresponding to your email choice, or leave blank to skip:\n"

email_choice=""
while true; do
    read -p "> " email_choice
    if [[ -z "$email_choice" ]]; then
        email=""
        break
    elif [[ "$email_choice" =~ ^[1-5]$ ]]; then
        email="${emails[$((email_choice-1))]}"
        break
    else
        printf "Invalid selection. Please enter a number between 1 and 5, or leave blank.\n"
    fi
done

# If username is still empty, use the selected email if available
if [[ -z "$Username" ]] && [[ -n "$email" ]]; then
    Username=$email
    printf "Using email '%s' as username.\n" "$email"
fi

# Final check for required Username after potential email fallback
if [[ -z "$Username" ]]; then
    error_exit "Username is required (either entered directly or selected via email). Please try again."
fi

# Prompt for Password if not provided via args
if [[ -z "$Password" ]]; then
    read -sp "Enter the Password (leave empty to generate a secure password): " Password_input
    printf "\n"
    Password="$Password_input"

    # Generate a secure password if still empty
    if [[ -z "$Password" ]]; then

        # Ask user for password generation mode
        generation_mode="" # Removed 'local'
        while [[ "$generation_mode" != "1" && "$generation_mode" != "2" && "$generation_mode" != "3" ]]; do
            printf "Choose password generation mode:\n"
            printf "  1) Random Secure (Recommended: Random length 18-30, random requirements 1-4 each)\n"
            printf "  2) Default Secure (Use script defaults: Length=%s, Mins=1)\n" "$INITIAL_DEFAULT_PW_LENGTH"
            printf "  3) Custom Requirements (Specify length, minimums, etc.)\n"
            read -p "Enter 1, 2, or 3 [default: 1]: " mode_input
            generation_mode="${mode_input:-1}" # Default to Random Secure
            if [[ "$generation_mode" != "1" && "$generation_mode" != "2" && "$generation_mode" != "3" ]]; then
                printf "Invalid choice. Please enter 1, 2, or 3.\n"
            fi
        done

        if [[ "$generation_mode" == "1" ]]; then
            # --- Mode 1: Random Secure ---
            printf "Generating password with random secure settings...\n"
            # Random length between 18 and 30
            PasswordLength=$(( RANDOM % (30 - 18 + 1) + 18 ))
            # Random minimums (1-4), ensuring total doesn't exceed length easily
            max_each=4 # Ensure no 'local' here
            current_total=0 # Ensure no 'local' here
            while true; do
                MinUppercase=$(( RANDOM % max_each + 1 ))
                MinLowercase=$(( RANDOM % max_each + 1 ))
                MinDigits=$(( RANDOM % max_each + 1 ))
                MinSymbols=$(( RANDOM % max_each + 1 ))
                current_total=$(( MinUppercase + MinLowercase + MinDigits + MinSymbols ))
                # Ensure total minimums are less than or equal to length
                if [[ "$current_total" -le "$PasswordLength" ]]; then
                    break
                fi
                # Optional: Reduce max_each if consistently failing, though unlikely with length >= 18
            done
            # Use default symbols for random secure mode
            CustomSymbols="$INITIAL_DEFAULT_CUSTOM_SYMBOLS"

            printf "Using random settings: Length=%s, Upper=%s, Lower=%s, Digits=%s, Symbols=%s\n" \
                 "$PasswordLength" "$MinUppercase" "$MinLowercase" "$MinDigits" "$MinSymbols"

        elif [[ "$generation_mode" == "2" ]]; then
             # --- Mode 2: Default Secure ---
             printf "Generating password with default secure settings...\n"
             # Ensure we use the initial defaults, overriding any flags if mode 2 is explicitly chosen interactively
             PasswordLength="$INITIAL_DEFAULT_PW_LENGTH"
             MinUppercase="$INITIAL_DEFAULT_MIN_UPPER"
             MinLowercase="$INITIAL_DEFAULT_MIN_LOWER"
             MinDigits="$INITIAL_DEFAULT_MIN_DIGITS"
             MinSymbols="$INITIAL_DEFAULT_MIN_SYMBOLS"
             CustomSymbols="$INITIAL_DEFAULT_CUSTOM_SYMBOLS"

             printf "Using default settings: Length=%s, Upper=%s, Lower=%s, Digits=%s, Symbols=%s\n" \
                 "$PasswordLength" "$MinUppercase" "$MinLowercase" "$MinDigits" "$MinSymbols"

        else
            # --- Mode 3: Custom Requirements ---
            printf "Using custom requirements mode...\n"
            # Prompt for requirements interactively only if they weren't set via flags
            # (i.e., if they still hold their initial default values)

            # Length
        if [[ "$PasswordLength" == "$INITIAL_DEFAULT_PW_LENGTH" ]]; then
             prompt_numeric "Enter password length [default: $PasswordLength]: " PasswordLength "$PasswordLength"
        fi
        # Min Uppercase
        if [[ "$MinUppercase" == "$INITIAL_DEFAULT_MIN_UPPER" ]]; then
            prompt_numeric "Minimum uppercase chars [default: $MinUppercase]: " MinUppercase "$MinUppercase"
        fi
        # Min Lowercase
        if [[ "$MinLowercase" == "$INITIAL_DEFAULT_MIN_LOWER" ]]; then
            prompt_numeric "Minimum lowercase chars [default: $MinLowercase]: " MinLowercase "$MinLowercase"
        fi
        # Min Digits
        if [[ "$MinDigits" == "$INITIAL_DEFAULT_MIN_DIGITS" ]]; then
            prompt_numeric "Minimum digits [default: $MinDigits]: " MinDigits "$MinDigits"
        fi
        # Min Symbols
        if [[ "$MinSymbols" == "$INITIAL_DEFAULT_MIN_SYMBOLS" ]]; then
            prompt_numeric "Minimum symbols [default: $MinSymbols]: " MinSymbols "$MinSymbols"
        fi
        # Custom Symbols
        if [[ "$CustomSymbols" == "$INITIAL_DEFAULT_CUSTOM_SYMBOLS" ]]; then
            read -p "Set of symbols to use [default: $CustomSymbols]: " CustomSymbols_input
            CustomSymbols="${CustomSymbols_input:-$CustomSymbols}" # Keep default if empty
        fi

            printf "Using custom settings: Length=%s, Upper=%s, Lower=%s, Digits=%s, Symbols=%s\n" \
                 "$PasswordLength" "$MinUppercase" "$MinLowercase" "$MinDigits" "$MinSymbols"
        fi

        # --- Actual Generation (Common to both modes) ---
        Password=$(generate_password_with_reqs "$PasswordLength" "$MinUppercase" "$MinLowercase" "$MinDigits" "$MinSymbols" "$CustomSymbols")
        printf "Generated secure password.\n" # Don't echo the password itself
    fi
fi

# --- Prepare Entry ---

# Apply camel case if requested
if [[ "$CamelCaseTitle" = true ]]; then
    Title=$(to_camel_case "$Title")
    printf "Applying CamelCase to title: %s\n" "$Title"
fi

# Define the entry path relative to the password store root
ENTRY_PATH="$Subdirectory/$Title"

# --- Create Entry ---

printf "Creating password entry: %s\n" "$ENTRY_PATH"
# Use Here Document to feed multi-line input to pass insert -m
pass insert -m "$ENTRY_PATH" <<EOF
$Password
user: $Username
$( [[ -n "$email" ]] && printf "email: %s\n" "$email" )
$( [[ -n "$URL" ]] && printf "url: %s\n" "$URL" )
EOF

printf "Password entry '%s' created successfully in '%s'.\n" "$Title" "$Subdirectory"

exit 0
