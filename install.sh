#!/bin/bash

# Define the URL of the script on GitHub
script_url="https://raw.githubusercontent.com/itislu/42free/main/42free.sh"

# Define the destination directory and filename
dest_dir="$HOME/.scripts"
dest_file="42free.sh"

# Download the script
mkdir -p "$dest_dir"
curl -Lo "$dest_dir/$dest_file" "$script_url"
echo -e "$dest_file downloaded into $dest_dir."

# Make the script executable
chmod +x "$dest_dir/$dest_file"

# Determine the shell and set the appropriate RC file
if [[ "$SHELL" == *"bash"* ]]; then
    RC_FILE="$HOME/.bashrc"
elif [[ "$SHELL" == *"zsh"* ]]; then
    RC_FILE="$HOME/.zshrc"
elif [[ "$SHELL" == *"fish"* ]]; then
    RC_FILE="$HOME/.config/fish/config.fish"
else
    echo -e "\e[1;31mUnsupported shell. Please set an alias for your shell manually.\e[0m"
    exit 1
fi

# Add an alias to the user's shell RC file if it doesn't exist
if ! grep "42free=" "$RC_FILE" &> /dev/null; then
    echo -e "\e[33m42free alias not present.\e[0m"
    echo -e "\e[33mAdding alias in file: $RC_FILE\e[0m"
    echo -e "\nalias 42free='bash $dest_dir/$dest_file'\n" >> "$RC_FILE"
fi

echo -e "\e[1;32mInstallation completed.\e[0m"
echo -e "You can now use the 42free command."
echo -e "For help, run \e[1m42free -h\e[0m."

# Start the default shell to make the alias available immediately
exec $SHELL
