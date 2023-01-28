#!/bin/bash
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
#yr-dlp needs to be installed with pip and the cutting edge version needs to be used:
