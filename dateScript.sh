#!/bin/bash

# Set the directory containing the files to be renamed
dir="/home/haashim/Downloads/Statements2"

# Loop through all files in the directory with names starting with "Statement--10978-62717871--"
for file in "$dir/Statement--10978-62717871--"*
do
    # Extract the date section of the file name
    date_section="$(echo "$file" | grep -oE '\-\-[0-9]{2}\-[0-9]{2}\-[0-9]{4}\-[0-9]{2}\-[0-9]{2}\-\-[0-9]{2}\-[0-9]{2}\-[0-9]{4}')"
    
    # Extract the start and end dates from the date section
    start_date="$(echo "$date_section" | grep -oE '[0-9]{2}\-[0-9]{2}\-[0-9]{4}' | head -1)"
    end_date="$(echo "$date_section" | grep -oE '[0-9]{2}\-[0-9]{2}\-[0-9]{4}' | tail -1)"
    
    # Construct the new file name with the updated date section
    new_file_name="$(echo "$file" | sed "s/$date_section/_${start_date}_to_${end_date}/")"
    
    # Rename the file with the new file name
    mv "$file" "$new_file_name"
done
