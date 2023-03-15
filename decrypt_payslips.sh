#!/bin/bash

# Set your desired password
PASSWORD="SUPER SECRET"

# Loop through each PDF file in the current directory
for INPUT_FILE in *.PDF; do
    # Generate a unique output file name based on the input file name
    OUTPUT_FILE="${INPUT_FILE%.*}-output.pdf"
    # Replace spaces in the output file name with underscores
    OUTPUT_FILE="${OUTPUT_FILE// /_}"
    # Run pdftk command with the current input and output file names
    qpdf --decrypt --password="$PASSWORD" "$INPUT_FILE" "$OUTPUT_FILE"
    pdftk "$INPUT_FILE" input_pw "$PASSWORD" output "$OUTPUT_FILE"
done
