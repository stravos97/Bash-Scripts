#!/bin/bash

#This code needs to be run in the folder with both the .jpg and .opus files
# This is currently a WIP. Matching is successful however ffmpeg fails in joining jpg into .opus

# Get current directory
#current_dir=$(pwd)

# Loop through all files in current directory
#for file in "$current_dir"/*; do
#    # Check if file is a regular file
#    if [[ $file == *"opus"* ]]; then
#        for file2 in "$current_dir"/*; do
#	  if [[ $file2 == *"jpg"* ]]; then
#	      ffmpeg -loop 1 -i "$file2" -i "$file" -c:v libvpx-vp9 -c:a libopus -b:a 48k -shortest -t 30 $file
#	  fi
#	 done
#    fi
#done


# Store the current directory in a variable
dir=$(pwd)

# Loop through all files in the current directory
for file in "$dir"/*; do
  # Get the file name without the extension
  base=$(basename "$file" .opus)

  # Check if there is a file with the same name but a different extension
  if [ -e "$dir/$base.jpg" ]; then
    # Execute code on the matching case
    ffmpeg -y -v verbose -loop 1 -i "$dir/$base.jpg" -i "$dir/$base.opus" -v error -c:v libvpx-vp9 -c:a libopus -b:a 48k -shortest -t 30 "$dir/$base.opus" -f null - 2>error.log
    echo "Found matching file: $base.jpg"
  fi
done
