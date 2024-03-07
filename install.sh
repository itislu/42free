#!/bin/bash

# Define the URL of the script on GitHub
script_url="https://raw.githubusercontent.com/itislu/42free/main/42free.sh"

# Define the destination directory and filename
dest_dir="$HOME/.scripts"
dest_file="42free.sh"

# Exit codes
success=0
download_failed=1
install_failed=2

# Colors and styles
sty_res="\e[0m"
sty_bol="\e[1m"
sty_red="\e[31m"
sty_yel="\e[33m"
sty_bri_gre="\e[92m"
sty_bri_yel="\e[93m"

# Automatically detects the size of the terminal window and preserves word boundaries at the edges
pretty_print()
{
    printf "%b" "$1" | fmt -sw $(tput cols)
}

# Check if curl or wget is available
if command -v curl &>/dev/null; then
    downloader="curl"
    downloader_opts="-sSLo"
elif command -v wget &>/dev/null; then
    downloader="wget"
    downloader_opts="-qO"
else
    pretty_print "Neither ${sty_bol}${sty_red}curl${sty_res} nor ${sty_bol}${sty_red}wget${sty_res} was found."
    pretty_print "Please install one of them and try again."
    exit $download_failed
fi

# Check if it's an update or a fresh install
if [[ $1 == "update" ]]; then
    pretty_print "${sty_yel}Updating '$dest_file' in '$dest_dir'...${sty_res}"
else
    pretty_print "${sty_yel}Downloading '$dest_file' into '$dest_dir'...${sty_res}"
fi

# Download the script
mkdir -p "$dest_dir"
$downloader $downloader_opts "$dest_dir/$dest_file" "$script_url"
exit_status=$?
if [ $exit_status -ne 0 ]; then
    pretty_print "${sty_bol}${sty_red}Failed to download file with $downloader.${sty_res}"
    exit $download_failed
fi

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
    pretty_print "${sty_bol}${sty_bri_yel}Unsupported shell. Please set an alias for your shell manually.${sty_res}"
    exit $install_failed
fi

# Add an alias to the user's shell RC file if it doesn't exist
if ! grep "42free=" "$RC_FILE" &>/dev/null; then
    pretty_print "${sty_yel}42free alias not present.${sty_res}"
    pretty_print "${sty_yel}Adding 42free alias in file '$RC_FILE'.${sty_res}"
    echo -e "\nalias 42free='bash $dest_dir/$dest_file'\n" >> "$RC_FILE"
    new_alias=true
else
    if [[ $1 != "update" ]]; then
        pretty_print "${sty_yel}42free alias already present.${sty_res}"
    fi
    new_alias=false
fi

# Check if it's an update or a fresh install
if [[ $1 == "update" ]]; then
    pretty_print "${sty_bol}${sty_bri_gre}Update completed.${sty_res}"
else
    pretty_print "${sty_bol}${sty_bri_gre}Installation completed.${sty_res}"
    pretty_print "You can now use the 42free command."
    pretty_print "For help, run '${sty_bol}42free -h${sty_res}'."
fi

if [[ $new_alias == true ]]; then
    # Start the default shell to make the alias available immediately
    if [ -x "$SHELL" ]; then
        exec $SHELL
    fi
    # If exec failed, inform the user to open a new shell
    pretty_print "Please open a new shell to make the 42free command available."
fi

exit $success
