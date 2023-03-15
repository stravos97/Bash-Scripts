#!/bin/bash

echo "Enter a string:"
read string

while true; do
  echo "Enter a number:"
  read num

  # Extract the character at the given position and print it
  char=${string:num-1:1}
  echo "The character at position $num in the string '$string' is '$char'"

  echo "Press any key to continue, or 'q' to quit."
  read -n1 input

  if [[ "$input" == "q" ]]; then
    break
  fi
done

