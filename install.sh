#!/bin/bash

# Define the URL of the latest release API endpoint
api_url="https://api.github.com/repos/itislu/42free/releases/latest"

# Dictionary of supported campuses
# Format: ["Campus Name"]="home_max_size sgoinfre_max_size"
declare -A campus_dict
campus_dict=(
["42 Berlin"]="10 30"
["42 Vienna"]="5 30"
["Other"]="0 0"
)

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
bash_rc="$HOME/.bashrc"
zsh_rc="$HOME/.zshrc"
fish_config="$HOME/.config/fish/config.fish"

# Exit codes
success=0
download_failed=1
install_failed=2

# Colors and styles
sty_res="\e[0m"
sty_bol="\e[1m"
sty_und="\e[4m"
sty_red="\e[31m"
sty_yel="\e[33m"
sty_bri_gre="\e[92m"
sty_bri_yel="\e[93m"
sty_bri_blu="\e[94m"

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

# Sort campus names by keys
mapfile -t campus_names_sorted < <(printf '%s\n' "${!campus_dict[@]}" | sort)

# Create list of campuses in this format: n) Campus Name
prompt_campuses=""
i=1
for campus_name in "${campus_names_sorted[@]}"; do
    prompt_campuses+="${sty_bol}$(( i++ ))${sty_res}) $campus_name\n"
done

# Make campus names array 1-indexed
campus_names_sorted=("" "${campus_names_sorted[@]}")

# Prompt user to choose their campus
while true; do
    pretty_print "${sty_bol}Choose your campus:${sty_res}"
    pretty_print "$prompt_campuses"
    read -rp "> "
    if [[ $REPLY =~ ^[0-9]+$ ]]; then
        campus_name=${campus_names_sorted[$REPLY]}
        if [[ -n "$campus_name" ]]; then
            IFS=' ' read -r home_max_size sgoinfre_max_size <<< "${campus_dict[$campus_name]}"
            break
        fi
    fi
    pretty_print "${sty_bol}${sty_red}Invalid option. Please try again.${sty_res}"
done

# If max_size not known, prompt user to enter it
if [[ $home_max_size -eq 0 ]]; then
    while true; do
        pretty_print "${sty_bol}Enter the maximum allowed size of your home directory in GB:${sty_res}"
        read -rp "> "
        if [[ $REPLY =~ ^[0-9]+$ ]]; then
            home_max_size=$REPLY
            break
        fi
        pretty_print "${sty_bol}${sty_red}Invalid input. Please enter a number.${sty_res}"
    done
fi
if [[ $sgoinfre_max_size -eq 0 ]]; then
    while true; do
        pretty_print "${sty_bol}Enter the maximum allowed size of your sgoinfre directory in GB:${sty_res}"
        read -rp "> "
        if [[ $REPLY =~ ^[0-9]+$ ]]; then
            sgoinfre_max_size=$REPLY
            break
        fi
        pretty_print "${sty_bol}${sty_red}Invalid input. Please enter a number.${sty_res}"
    done
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
for rc_file in "$bash_rc" "$zsh_rc" "$fish_config"; do
    case "$rc_file" in
        "$bash_rc")
            shell_name="bash"
            ;;
        "$zsh_rc")
            shell_name="zsh"
            ;;
        "$fish_config")
            shell_name="fish"
            ;;
    esac
    if [ -f "$rc_file" ]; then
        if ! grep "alias 42free=" "$rc_file" &>/dev/null; then
            echo -e "\nalias 42free='bash $dest_dir/$dest_file'\n" >> "$rc_file"
            pretty_print "${sty_yel}Added 42free alias to $shell_name.${sty_res}"
            new_alias=true
        fi
        if ! grep "export HOME_MAX_SIZE=" "$rc_file" &>/dev/null; then
            echo -e "\nexport HOME_MAX_SIZE=$home_max_size\n" >> "$rc_file"
            pretty_print "${sty_yel}Added HOME_MAX_SIZE environment variable to $shell_name.${sty_res}"
        fi
        if ! grep "export SGOINFRE_MAX_SIZE=" "$rc_file" &>/dev/null; then
            echo -e "\nexport SGOINFRE_MAX_SIZE=$sgoinfre_max_size\n" >> "$rc_file"
            pretty_print "${sty_yel}Added SGOINFRE_MAX_SIZE environment variable to $shell_name.${sty_res}"
        fi
    fi
done

# Check user's default shell
if [[ "$SHELL" != *"bash"* && "$SHELL" != *"zsh"* && "$SHELL" == *"fish"* ]]; then
    pretty_print "${sty_bol}${sty_bri_yel}Could not set up 42free for $(basename "$SHELL"). Please do it manually.${sty_res}"
    pretty_print "${sty_bol}${sty_bri_yel}You can paste the following lines into your shell's configuration file:"
    pretty_print "${sty_bol}alias 42free='bash $dest_dir/$dest_file'${sty_res}"
    pretty_print "${sty_bol}export HOME_MAX_SIZE=$home_max_size${sty_res}"
    pretty_print "${sty_bol}export SGOINFRE_MAX_SIZE=$sgoinfre_max_size${sty_res}"
    exit $install_failed
fi

# Check if it's an update or a fresh install
if [[ $1 == "update" ]]; then
    pretty_print "${sty_bol}${sty_bri_gre}Update completed.${sty_res}"
    pretty_print "To see the changelog, visit ${sty_und}${sty_bri_blu}https://github.com/itislu/42free/releases${sty_res}."
else
    pretty_print "${sty_bol}${sty_bri_gre}Installation completed.${sty_res}"
    pretty_print "You can now use the '${sty_bol}42free${sty_res}' command."
    pretty_print "To see the manual, run '42free --help'."
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
