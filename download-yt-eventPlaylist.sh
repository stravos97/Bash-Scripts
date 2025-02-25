#!/bin/bash

# YouTube Playlist Downloader
# Downloads videos from a YouTube playlist and converts them to audio format

# Configuration
LOG_FILE="yt_dl_log.txt"
ERROR_LOG="yt_dl_error.txt"
DEFAULT_PLAYLIST="https://www.youtube.com/playlist?list=PLKm-SN1_VQ8VOpmmI26BdiTQ61cR0vH-6"
DEFAULT_OUTPUT_DIR="Event"
DEFAULT_AUDIO_FORMAT="opus"
DEFAULT_AUDIO_QUALITY="320k"
ARCHIVE_FILE="archive.txt"

# Initialize log files with timestamps
echo "$(date +'%Y-%m-%d %H:%M:%S') Starting YouTube Playlist Downloader" | tee -a "$LOG_FILE"

# Function to show script usage
show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -p, --playlist URL    YouTube playlist URL (default: $DEFAULT_PLAYLIST)"
    echo "  -d, --directory DIR   Output directory name (default: $DEFAULT_OUTPUT_DIR)"
    echo "  -f, --format FORMAT   Audio format (opus, mp3, m4a) (default: $DEFAULT_AUDIO_FORMAT)"
    echo "  -q, --quality VALUE   Audio quality (128k, 256k, 320k) (default: $DEFAULT_AUDIO_QUALITY)"
    echo "  -r, --rate RATE       Download rate limit (default: 100K)"
    echo "  -h, --help            Show this help message"
    echo ""
    exit 1
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp [$level] $message" | tee -a "$LOG_FILE"
    
    if [[ "$level" == "ERROR" ]]; then
        echo "$timestamp [$level] $message" >> "$ERROR_LOG"
    fi
}

# Function to check and install packages using apt
install_apt_package() {
    local package=$1
    log_message "INFO" "Checking for $package..."
    
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "ok installed"; then
        log_message "INFO" "$package is not found, installing..."
        if ! sudo apt-get install -y "$package"; then
            log_message "ERROR" "Failed to install $package"
            exit 1
        fi
        log_message "INFO" "$package installed successfully"
    else
        log_message "INFO" "$package is already installed"
    fi
}

# Function to check and install packages using pip3
install_pip3_package() {
    local package=$1
    local pip_arg=${2:-"$package"}
    
    log_message "INFO" "Checking for Python package $package..."
    
    if ! pip3 freeze | grep -qi "^$package="; then
        log_message "INFO" "$package is not found, installing..."
        if ! python3 -m pip install -U "$pip_arg"; then
            log_message "ERROR" "Failed to install $package"
            exit 1
        fi
        log_message "INFO" "$package installed successfully"
    else
        log_message "INFO" "$package is already installed"
    fi
}

# Function to setup environment
setup_environment() {
    # Update package lists
    log_message "INFO" "Updating package lists..."
    sudo apt-get update

    # Install system dependencies
    install_apt_package "python3"
    install_apt_package "python3-pip"
    install_apt_package "ffmpeg"
    install_apt_package "aria2"

    # Install Python dependencies
    install_pip3_package "wheel"
    install_pip3_package "pip"
    install_pip3_package "pyxattr"
    
    # Install or update yt-dlp from GitHub to get the latest version
    log_message "INFO" "Installing/updating yt-dlp from GitHub..."
    python3 -m pip install --force-reinstall https://github.com/yt-dlp/yt-dlp/archive/master.tar.gz
    
    # Add local bin to PATH if needed
    if [[ ":$PATH:" != *":/home/$USER/.local/bin:"* ]]; then
        log_message "INFO" "Adding ~/.local/bin to PATH..."
        
        # Check which shell is being used and update the appropriate rc file
        if [[ "$SHELL" == *"zsh"* ]]; then
            echo 'export PATH="/home/$USER/.local/bin:$PATH"' >> ~/.zshrc
            log_message "INFO" "Updated ~/.zshrc with PATH"
        elif [[ "$SHELL" == *"bash"* ]]; then
            echo 'export PATH="/home/$USER/.local/bin:$PATH"' >> ~/.bashrc
            log_message "INFO" "Updated ~/.bashrc with PATH"
        else
            log_message "WARNING" "Unknown shell: $SHELL. Please manually add ~/.local/bin to your PATH"
        fi
        
        # Also set for the current session
        export PATH="/home/$USER/.local/bin:$PATH"
    else
        log_message "INFO" "~/.local/bin already in PATH"
    fi
}

# Function to download playlist
download_playlist() {
    local playlist_url="$1"
    local output_dir="$2"
    local download_rate="$3"
    
    # Create directory if it doesn't exist
    mkdir -p "$output_dir"
    
    log_message "INFO" "Downloading playlist: $playlist_url to $output_dir"
    
    # Run yt-dlp with specified options
    if ! yt-dlp --format "ba" \
         -o "$output_dir/%(title)s-%(uploader)s.%(ext)s" \
         "$playlist_url" \
         --throttled-rate "$download_rate" \
         --verbose \
         --force-ipv4 \
         --sleep-requests 1 \
         --sleep-interval 5 \
         --downloader aria2c \
         --max-sleep-interval 30 \
         --ignore-errors \
         --download-archive "$ARCHIVE_FILE" \
         --no-post-overwrites \
         --write-thumbnail \
         --embed-thumbnail \
         --extract-audio \
         --add-metadata \
         --parse-metadata "%(title)s:%(meta_title)s" \
         --parse-metadata "%(artist)s:%(meta_artist)s" \
         --check-formats \
         --xattrs \
         --concurrent-fragments 5; then
         
        log_message "ERROR" "Failed to download playlist"
        return 1
    fi
    
    log_message "INFO" "Download completed successfully"
    return 0
}

# Function to convert audio files
convert_audio_files() {
    local dir="$1"
    local format="$2"
    local quality="$3"
    local conversion_count=0
    local total_files=$(find "$dir" -type f -name "*.opus" -o -name "*.m4a" -o -name "*.webm" | wc -l)
    
    log_message "INFO" "Converting $total_files files to $format format with quality $quality"
    
    # Create a temporary directory for converted files
    local temp_dir="${dir}_converted"
    mkdir -p "$temp_dir"
    
    # Process each file
    find "$dir" -type f -name "*.opus" -o -name "*.m4a" -o -name "*.webm" | while read -r file; do
        # Extract metadata
        local title=$(ffprobe -loglevel error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$file" || echo "Unknown Title")
        local artist=$(ffprobe -loglevel error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$file" || echo "Unknown Artist")
        
        # If title or artist are empty, use the filename
        if [[ -z "$title" || "$title" == "Unknown Title" ]]; then
            title=$(basename "$file" | sed 's/\.[^.]*$//')
        fi
        
        # Sanitize filename
        local safe_title=$(echo "$title" | tr -dc '[:alnum:] ._-')
        local safe_artist=$(echo "$artist" | tr -dc '[:alnum:] ._-')
        local output_file="$temp_dir/${safe_title}${safe_artist:+ - $safe_artist}.$format"
        
        log_message "INFO" "Converting: $file to $output_file"
        
        # Convert the file
        if ffmpeg -y -i "$file" -v quiet -stats \
            -vn -acodec ${format == "mp3" ? "libmp3lame" : format} \
            -b:a "$quality" -ar 44100 \
            -metadata title="$title" \
            -metadata artist="$artist" \
            "$output_file"; then
            
            conversion_count=$((conversion_count + 1))
            log_message "INFO" "Successfully converted ($conversion_count/$total_files): $output_file"
        else
            log_message "ERROR" "Failed to convert: $file"
        fi
    done
    
    # Process thumbnails if any
    find "$dir" -type f -name "*.webp" -o -name "*.jpg" | while read -r thumbnail; do
        local base_name=$(basename "$thumbnail" | sed 's/\.[^.]*$//')
        local output_thumbnail="$temp_dir/${base_name}.jpg"
        
        log_message "INFO" "Converting thumbnail: $thumbnail to $output_thumbnail"
        
        if ! ffmpeg -y -i "$thumbnail" -v quiet -q:v 1 -bsf:v mjpeg2jpeg "$output_thumbnail"; then
            log_message "ERROR" "Failed to convert thumbnail: $thumbnail"
        fi
    done
    
    # Ask user if they want to replace original files
    if [[ $conversion_count -gt 0 ]]; then
        echo ""
        echo "Converted $conversion_count files to $format format."
        read -p "Do you want to move converted files to the original directory? (y/n): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_message "INFO" "Moving converted files to original directory"
            mv "$temp_dir"/* "$dir"/ 2>/dev/null
            log_message "INFO" "Files moved successfully"
        else
            log_message "INFO" "Converted files are in: $temp_dir"
        fi
    else
        log_message "WARNING" "No files were converted"
        rm -rf "$temp_dir"
    fi
}

# Parse command-line arguments
PLAYLIST_URL="$DEFAULT_PLAYLIST"
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
AUDIO_FORMAT="$DEFAULT_AUDIO_FORMAT"
AUDIO_QUALITY="$DEFAULT_AUDIO_QUALITY"
DOWNLOAD_RATE="100K"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--playlist)
            PLAYLIST_URL="$2"
            shift 2
            ;;
        -d|--directory)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -f|--format)
            AUDIO_FORMAT="$2"
            shift 2
            ;;
        -q|--quality)
            AUDIO_QUALITY="$2"
            shift 2
            ;;
        -r|--rate)
            DOWNLOAD_RATE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            log_message "ERROR" "Unknown option: $1"
            show_usage
            ;;
    esac
done

# Validate audio format
if [[ ! "$AUDIO_FORMAT" =~ ^(opus|mp3|m4a)$ ]]; then
    log_message "ERROR" "Invalid audio format: $AUDIO_FORMAT. Must be opus, mp3, or m4a"
    exit 1
fi

# Main execution flow
echo "============================================================"
echo "  YouTube Playlist Downloader"
echo "============================================================"
echo "Playlist URL: $PLAYLIST_URL"
echo "Output Directory: $OUTPUT_DIR"
echo "Audio Format: $AUDIO_FORMAT"
echo "Audio Quality: $AUDIO_QUALITY"
echo "Download Rate: $DOWNLOAD_RATE"
echo "============================================================"

# Confirm with user
read -p "Do you want to proceed with these settings? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_message "INFO" "Operation canceled by user"
    exit 0
fi

# Setup the environment
setup_environment

# Download the playlist
if ! download_playlist "$PLAYLIST_URL" "$OUTPUT_DIR" "$DOWNLOAD_RATE"; then
    log_message "ERROR" "Failed to download playlist. Check the error log for details."
    exit 1
fi

# Convert the audio files
convert_audio_files "$OUTPUT_DIR" "$AUDIO_FORMAT" "$AUDIO_QUALITY"

# Complete
log_message "INFO" "All operations completed successfully"
echo "============================================================"
echo "  Download and Conversion Complete"
echo "============================================================"
echo "Check $OUTPUT_DIR for your files"
echo "Log file: $LOG_FILE"
echo "Error log: $ERROR_LOG"
echo "============================================================"

exit 0
