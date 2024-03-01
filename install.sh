#!/bin/bash

# Define the URL of the script on GitHub
script_url="https://raw.githubusercontent.com/itislu/42free/main/42free.sh"

# Define the destination directory and filename
dest_dir="$HOME/.scripts/"
dest_file="42free.sh"

# Download the script
mkdir -p "$dest_dir"
curl -Lo "$dest_dir/$dest_file" "$script_url"

# Make the script executable
chmod +x "$dest_dir/$dest_file"

# Determine the shell and set the appropriate RC file
RC_FILE="$HOME/.bashrc"
if [[ "$SHELL" == *"zsh"* ]]; then
    RC_FILE="$HOME/.zshrc"
fi

# Add an alias to the user's shell RC file if it doesn't exist
if ! grep "42free=" $RC_FILE &> /dev/null; then
    echo "42free alias not present"
    echo "Adding alias in file: $RC_FILE"
    echo -e "\nalias 42free='bash $dest_dir/$dest_file'\n" >> $RC_FILE
fi

# Source the RC file to make the alias available immediately
source $RC_FILE

echo "Installation completed. You can now use the \`42free\` command."
echo "For information on how to use 42free, run \`42free -h\`."
