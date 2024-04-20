#!/bin/bash

# Define the URL of the latest release API endpoint
api_url="https://api.github.com/repos/itislu/42free/releases/latest"

# Define the destination directory and filename
dest_dir="$HOME/.scripts"
dest_file="42free.sh"

# Check if curl or wget is available
if command -v curl &>/dev/null; then
    downloader="curl"
    downloader_opts_stdout="-sSL"
    downloader_opts_file="-sSLo"
elif command -v wget &>/dev/null; then
    downloader="wget"
    downloader_opts_stdout="-qO-"
    downloader_opts_file="-qO"
fi

# RC files
BASH_RC="$HOME/.bashrc"
ZSH_RC="$HOME/.zshrc"
FISH_CONFIG="$HOME/.config/fish/config.fish"

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
if [ -z "$downloader" ]; then
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

# Get the URL of the asset from the latest release
script_url=$("$downloader" "$downloader_opts_stdout" "$api_url" | grep "browser_download_url" | cut -d '"' -f 4)

# Download the script
mkdir -p "$dest_dir"
"$downloader" "$downloader_opts_file" "$dest_dir/$dest_file" "$script_url"
exit_status=$?
if [ $exit_status -ne 0 ]; then
    pretty_print "${sty_bol}${sty_red}Failed to download file with $downloader.${sty_res}"
    exit $download_failed
fi

# Make the script executable
chmod +x "$dest_dir/$dest_file"

# Add an alias to all supported RC files if it doesn't exist yet
for RC_FILE in "$BASH_RC" "$ZSH_RC" "$FISH_CONFIG"; do
    case "$RC_FILE" in
        "$BASH_RC")
            SHELL_NAME="bash"
            ;;
        "$ZSH_RC")
            SHELL_NAME="zsh"
            ;;
        "$FISH_CONFIG")
            SHELL_NAME="fish"
            ;;
    esac
    if [ -f "$RC_FILE" ] && ! grep "alias 42free=" "$RC_FILE" &>/dev/null; then
        echo -e "\nalias 42free='bash $dest_dir/$dest_file'\n" >> "$RC_FILE"
        pretty_print "${sty_yel}Added 42free alias to $SHELL_NAME.${sty_res}"
        new_alias=true
    fi
done

# Check user's default shell
if [[ "$SHELL" != *"bash"* && "$SHELL" != *"zsh"* && "$SHELL" == *"fish"* ]]; then
    pretty_print "${sty_bol}${sty_bri_yel}Could not set the 42free alias for $(basename "$SHELL"). Please set it manually.${sty_res}"
    exit $install_failed
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
    # If exec failed, inform the user to start a new shell
    pretty_print "Please start a new shell to make the 42free command available."
fi

exit $success
