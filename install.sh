#!/bin/bash

# Define the URL of the latest release API endpoint
api_url="https://api.github.com/repos/itislu/42free/releases/latest"

# Dictionary of supported campuses
# Format: ["Campus Name"]="home_max_size sgoinfre_max_size"
declare -A campus_dict
campus_dict=(
["42 Vienna"]="5 30"
["42 Berlin"]="5 30"
["Other"]="0 0"
)

# Define the destination directory and filename
dest_dir="$HOME/.scripts"
dest_file="42free.sh"

# Shell config files
bash_config="$HOME/.bashrc"
zsh_config="$HOME/.zshrc"
fish_config="$HOME/.config/fish/config.fish"

# Max sizes in GB
if [[ -n "$HOME_MAX_SIZE" ]] && [[ "$HOME_MAX_SIZE" =~ ^[0-9]+$ ]]; then
    home_max_size=$HOME_MAX_SIZE
fi
if [[ -n "$SGOINFRE_MAX_SIZE" ]] && [[ "$SGOINFRE_MAX_SIZE" =~ ^[0-9]+$ ]]; then
    sgoinfre_max_size=$SGOINFRE_MAX_SIZE
fi

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

# Exit codes
success=0
download_failed=1
install_failed=2

# Flags
changed_config=false

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

ft_exit()
{
    if $changed_config; then
        # Start the default shell to make changes of the shell config available immediately
        if [[ $1 -eq 0 ]] && [[ -x "$SHELL" ]]; then
            exec $SHELL
        fi
        # If exec failed, inform the user to start a new shell
        pretty_print "Please start a new shell to make the 42free configs available."
    fi
    exit "$1"
}

add_to_config()
{
    local config_file=$1
    local pattern=$2
    local line=$3
    local msg=$4

    if ! grep "$pattern" "$config_file" &>/dev/null; then
        if ! $changed_config; then
            printf "\n" >> "$config_file"
        fi
        printf "%s\n" "$line" >> "$config_file"
        pretty_print "${sty_yel}$msg${sty_res}"
        changed_config=true
    fi
}

# Check if it's an update or a fresh install
if [[ $1 == "update" ]]; then
    pretty_print "${sty_yel}Updating 42free...${sty_res}"
else
    pretty_print "${sty_yel}Installing 42free...${sty_res}"
fi

# Check if curl or wget is available
if [[ -z "$downloader" ]]; then
    pretty_print "Neither ${sty_bol}${sty_red}curl${sty_res} nor ${sty_bol}${sty_red}wget${sty_res} was found."
    pretty_print "Please install one of them and try again."
    exit $download_failed
fi

# Prompt user to choose their campus if max sizes are 0 or not known
if { [[ -z "$home_max_size" ]] || [[ $home_max_size -eq 0 ]]; } &&
   { [[ -z "$sgoinfre_max_size" ]] || [[ $sgoinfre_max_size -eq 0 ]]; }; then
    # Sort campus names by keys
    mapfile -t campus_names_sorted < <(printf '%s\n' "${!campus_dict[@]}" | sort)

    # Create list of campuses in this format: n) Campus Name
    i=1
    for campus_name in "${campus_names_sorted[@]}"; do
        prompt_campuses+="${sty_bol}$(( i++ ))${sty_res}) $campus_name\n"
    done

    # Make campus names array 1-indexed
    campus_names_sorted=("" "${campus_names_sorted[@]}")

    # Prompt user
    # Allow case-insensitive matching
    shopt -s nocasematch
    while true; do
        pretty_print "${sty_bol}Choose your campus:${sty_res}"
        pretty_print "$prompt_campuses"
        read -rp "> "
        valid_choice=false

        # Check if input is a valid number of the list
        if [[ $REPLY =~ ^[0-9]+$ ]] && [[ -n ${campus_names_sorted[$REPLY]} ]]; then
            campus_name=${campus_names_sorted[$REPLY]}
            valid_choice=true
        elif [[ -n "$REPLY" ]]; then
            # Check if input is a campus name
            for campus_name in "${campus_names_sorted[@]}"; do
                name_part="${campus_name#[0-9]* }"
                if [[ "$campus_name" == "$REPLY" ]] || [[ "$name_part" == "$REPLY" ]]; then
                    valid_choice=true
                    break
                fi
            done
        fi

        # If valid choice, set max size variables
        if $valid_choice; then
            IFS=' ' read -r home_max_size sgoinfre_max_size <<< "${campus_dict[$campus_name]}"
            break
        fi
        pretty_print "${sty_bol}${sty_red}Invalid input. Please enter a valid number or your campus name.${sty_res}"
    done
    shopt -u nocasematch
fi

# If a max size still not known, prompt user to enter it
for dir in home sgoinfre; do
    # Construct variable name
    max_size_var_name="${dir}_max_size"

    # If a max size still 0 or not known, prompt user to enter it
    if [[ -z "${!max_size_var_name}" ]] || [[ ${!max_size_var_name} -eq 0 ]]; then
        while true; do
            pretty_print "Enter the maximum allowed size of your ${sty_bol}$dir${sty_res} directory in GB:"
            read -rp "> "
            if [[ $REPLY =~ ^[0-9]+$ ]]; then
                declare "$max_size_var_name=$REPLY"
                break
            fi
            pretty_print "${sty_bol}${sty_red}Invalid input. Please enter a number.${sty_res}"
        done
    fi
done

pretty_print "${sty_yel}Downloading '$dest_file' into '$dest_dir'...${sty_res}"

# Get the URL of the asset from the latest release
script_url=$("$downloader" "$downloader_opts_stdout" "$api_url" | grep "browser_download_url" | cut -d '"' -f 4)

# Download the script
mkdir -p "$dest_dir"
"$downloader" "$downloader_opts_file" "$dest_dir/$dest_file" "$script_url"
exit_status=$?
if [[ $exit_status -ne 0 ]]; then
    pretty_print "${sty_bol}${sty_red}Failed to download file with $downloader.${sty_res}"
    exit $download_failed
fi

# Make the script executable
chmod +x "$dest_dir/$dest_file"

# Add an alias to all supported shell config files if it doesn't exist yet
for config_file in "$bash_config" "$zsh_config" "$fish_config"; do
    case "$config_file" in
        "$bash_config")
            shell_name="bash"
            ;;
        "$zsh_config")
            shell_name="zsh"
            ;;
        "$fish_config")
            shell_name="fish"
            ;;
    esac
    if [[ -f "$config_file" ]]; then
        msg="Added 42free alias to $shell_name."
        add_to_config "$config_file" "alias 42free=" "alias 42free='bash $dest_dir/$dest_file'" "$msg"
        msg="Added HOME_MAX_SIZE environment variable to $shell_name."
        add_to_config "$config_file" "export HOME_MAX_SIZE=" "export HOME_MAX_SIZE=$home_max_size" "$msg"
        msg="Added SGOINFRE_MAX_SIZE environment variable to $shell_name."
        add_to_config "$config_file" "export SGOINFRE_MAX_SIZE=" "export SGOINFRE_MAX_SIZE=$sgoinfre_max_size" "$msg"
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
else
    pretty_print "${sty_bol}${sty_bri_gre}Installation completed.${sty_res}"
    pretty_print "You can now use the '${sty_bol}42free${sty_res}' command."
    pretty_print "To see the manual, run '42free --help'."
fi

ft_exit $success
