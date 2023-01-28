#!/bin/bash

#Note this script has a dependency of zsh being your shell. If it's not modify this line "export PATH="/home/$USER/.local/bin:$PATH" >> ~/.zshrc" to point to your bashrc. Zsh can also be installed using the zsh-setup.sh script

sudo apt-get update

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null 
then
    # If not, install it
    echo "Python3 is not found, installing..."
    sudo apt-get install -y python3.11
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null 
then
    # If not, install it
    echo "pip3 is not found, installing..."
    sudo apt-get install -y python3-pip
fi

# Check if pip setuptools wheel are installed
if ! pip3 freeze | grep -q setuptools || ! pip3 freeze | grep -q wheel || ! pip3 freeze | grep -q pip || ! pip3 freeze | grep -q pyxattr
then
    # If not, install them
    echo "setuptools and wheel, pip, pyxattr are not found, installing..."
    python3 -m pip install -U pip setuptools wheel pyxattr
else 
    echo "setuptools and wheel, pip, pyxattr are already installed."
fi

# Check if yt-dlp is installed
#TODO: Move this line (export path) outside func and check if this already exists in ~/.zshrc, if it doesn't then add it
if ! pip3 freeze | grep -q yt-dlp 
then
    # If not, install them
    echo "yt-dlp has not been found, installing..."
    python3 -m pip install --force-reinstall https://github.com/yt-dlp/yt-dlp/archive/master.tar.gz
    export PATH="/home/$USER/.local/bin:$PATH" >> ~/.zshrc
else
    echo "yt-dlp has already been installed."
fi

# Check if ffmpeg is already installed (ffprobe is installed with ffmpeg)
if ! command -v ffmpeg > /dev/null 2>&1; then
  # If not, install it
  sudo apt-get install -y ffmpeg
  echo "ffmpeg has been installed."
else
  echo "ffmpeg is already installed."
fi

# Check if the line exists in .zshrc
# Once complete remove from download yt-dl function
#if ! grep -q "export PATH='/home/$USER/.local/bin:$PATH'" ~/.zshrc; then
  # If not, add it to the bottom of the file
#  echo "export PATH='/home/$USER/.local/bin:$PATH'" >> ~/.zshrc
#  echo "Added the line to ~/.zshrc"
#else
#  echo "The line is already present in ~/.zshrc"
#fi


#Set the YouTube channel URL

channel_url="https://www.youtube.com/playlist?list=PLKm-SN1_VQ8VOpmmI26BdiTQ61cR0vH-6"
#Get all playlists from the channel

#playlists=$(yt-dlp -o "%(playlist_title)s" --flat-playlist --playlist-end 1 --skip-download "$channel_url" | tail -n 1 )
playlist="Event"
#Create a directory for the playlist

dir_name=$(echo $playlist)
mkdir $dir_name
#Download the videos in the playlist

yt-dlp --format "(bestaudio[acodec^=opus]/bestaudio)/best" -o "$dir_name/%(title)s-%(uploader)s.%(ext)s" "$channel_url" --throttled-rate 100K --verbose --force-ipv4 --sleep-requests 1 --sleep-interval 5 --max-sleep-interval 30 --ignore-errors --no-overwrites --write-annotations --write-thumbnail --embed-thumbnail --extract-audio --add-metadata --parse-metadata "%(title)s:%(meta_title)s" --parse-metadata "%(artist)s:%(meta_artist)s" --check-formats --xattrs --concurrent-fragments 5
#Convert all videos in the directory to audio-only files

#Convert all videos in the directory to audio-only files
for file in $dir_name/*; do
    if [[ $file == *"opus"* ]]; then
        title=$(ffprobe -loglevel error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$file")
        artist=$(ffprobe -loglevel error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$file")
        ffmpeg -i "$file" -vn -acodec opus -b:a 320k -ar 44100 -y "${title} - ${artist}.opus"
    elif [[ $file == *"webp"* ]]; then
	 ffmpeg -i "$file" -q:v 1 -bsf:v mjpeg2jpeg "${file%.webp}.jpg"
    fi
done

echo "All playlists have been downloaded and converted to audio-only files."

#script should only download from event etc playlist
