#!/usr/bin/env bash

# Exit codes
success=0
download_failed=1
install_failed=2
compatibility_issue=3

# Check OS
os_name=$(uname -s)
if [[ "$os_name" != "Linux" ]] && [[ "$os_name" != "Darwin" ]]; then
    echo "42free currently only supports Linux and macOS. Sorry :("
    exit $compatibility_issue
fi

# Define the URL of the latest release API endpoint
latest_release_url="https://api.github.com/repos/itislu/42free/releases/latest"

# Array of supported campuses
# ! Add new campuses to END of list ! (will be sorted alphanumerically later)
# Format: "Campus Name;home_max_size;sgoinfre_max_size;home_upgraded_size;sgoinfre_upgraded_size"
campuses=(
    "Other;-;-;-;-"
    "42 Vienna;5;30;10;-"
    "42 Berlin;5;30;-;-"
    "19 Brussels;5;15;-;-"
    "42 Bangkok;10;15;20;-"
    "42 Lisboa;5;30;-;-"
    "42 Gyeongsan;5;0;-;42"
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

# Flags
changed_config=false

# Text formatting
reset="\033[0m"
bold="\033[1m"
red="\033[31m"
yellow="\033[33m"
bright_green="\033[92m"
bright_yellow="\033[93m"

# Automatically detect the size of the terminal window and preserve word boundaries
pretty_print() {
    local terminal_width
    local lines

    # Get terminal width
    terminal_width=$(tput cols)

    # Limit terminal width to 80 characters
    if (( terminal_width > 80 )); then
        terminal_width=80
    fi
    # Decrease by 5 to ensure it does not wrap around just before the actual end
    (( terminal_width -= 5 ))

    # Split argument into an array and print each line individually with consistent formatting
    IFS=$'\n' read -rd '' -a lines <<< "$1"
    for line in "${lines[@]}"; do
        printf "%b\n" "$(fmt -w $terminal_width <<< "$line")"
    done
}

ft_exit() {
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

ft_read() {
    read "$@"
    local status=$?
    if [[ $status -ne 0 ]]; then
        echo
    fi
    return $status
}

# Prompt the user for confirmation
# If optional second parameter contains 'y' or 'Y', default to 'yes'
# Otherwise, default to 'no' and 'yes' needs y/Y/yes,Yup,ya,... + Enter key
# Regex: Match Y/y, optionally followed by one valid char, or 2+ valid chars after which one invalid is allowed
prompt_user() {
    local prompt_text=$1
    local default_yes=$2
    local indicator
    local chset="YyEeAaUuSsHhPp"

    if [[ -n "$default_yes" ]] && [[ "$default_yes" =~ [Yy] ]]; then
        indicator="[${bold}Y${reset}/${bold}n${reset}]"
    else
        indicator="[${bold}y${reset}/${bold}N${reset}]"
        unset default_yes
    fi

    pretty_print "$prompt_text $indicator"
    ft_read -rp "> "
    if [[ "$REPLY" =~ ^[Yy]([$chset]|[$chset]{2,}([^$chset][$chset]*)?)?$ ]] ||
        { [[ -n "$default_yes" ]] && [[ "$REPLY" =~ ^$ ]]; }; then
        return 0
    fi
    return 1
}

sed_inplace() {
    local script=$1
    local file=$2

    if [[ "$os_name" == "Linux" ]]; then
        sed -i "$script" "$file"
    elif [[ "$os_name" == "Darwin" ]]; then
        sed -i "" "$script" "$file"
    fi
}

# Change or add a line in a shell config file
change_config() {
    local line=$1
    local config_file=$2

    if ! grep -q "^${line%%=*}=" "$config_file"; then
        mkdir -p "$(dirname "$config_file")"
        if [[ -n "$(tail -c 1 "$config_file")" ]]; then
            printf "\n" >> "$config_file"
        fi
        printf "%s\n" "$line" >> "$config_file"
        changed_config=true
        return 0
    elif ! grep -q "^$line$" "$config_file"; then
        # Escape any special characters
        line=$(printf "%q" "$line")
        sed_inplace "s'^${line%%=*}=.*'$line'" "$config_file"
        changed_config=true
        return 0
    fi
    return 1
}

# Check if it's an update or a fresh install
if [[ $1 == "update" ]]; then
    pretty_print "${yellow}Updating 42free...${reset}"
else
    pretty_print "${yellow}Installing 42free...${reset}"
fi

# Check if curl or wget is available
if [[ -z "$downloader" ]]; then
    pretty_print "Neither ${bold}${red}curl${reset} nor ${bold}${red}wget${reset} was found."
    pretty_print "Please install one of them and try again."
    exit $download_failed
fi

# Prompt user to choose their campus if both max sizes are not known
if [[ -z "$home_max_size" ]] && [[ -z "$sgoinfre_max_size" ]]; then

    # Sort the campuses array alphanumerically
    IFS=$'\n' read -rd '' -a campuses_sorted <<< "$(printf "%s\n" "${campuses[@]}" | sort -f)"

    # Iterate through the sorted campuses array and split the strings by semicolon into separate arrays
    for campus in "${campuses_sorted[@]}"; do
        IFS=';' read -r campus_name home_max_size sgoinfre_max_size home_upgraded_size sgoinfre_upgraded_size <<< "$campus"
        campus_names+=("$campus_name")
        home_max_sizes+=("$home_max_size")
        sgoinfre_max_sizes+=("$sgoinfre_max_size")
        home_upgraded_sizes+=("$home_upgraded_size")
        sgoinfre_upgraded_sizes+=("$sgoinfre_upgraded_size")
    done

    # Create list of campuses in this format: n) Campus Name
    i=1
    for campus_name in "${campus_names[@]}"; do
        prompt_campuses+=("${bold}$(( i++ ))${reset}) $campus_name")
    done

    # Prompt user
    # Allow case-insensitive matching
    shopt -s nocasematch
    while true; do
        pretty_print "${bold}Choose your campus:${reset}"
        printf "%b\n" "${prompt_campuses[@]}"
        printf "\n"
        ft_read -rp "> "

        # Check if input is a valid number of the list
        if [[ $REPLY =~ ^[0-9]+$ ]] && [[ $REPLY -ge 1 ]] && [[ $REPLY -le ${#campus_names[@]} ]]; then
            # Zero-index the choice
            campus_choice=$(( REPLY - 1 ))
        # Check if input is a campus name or the non-numeric part of it
        elif [[ -n "$REPLY" ]]; then
            for i in "${!campus_names[@]}"; do
                if [[ "$REPLY" == "${campus_names[$i]}" ]] || [[ "$REPLY" == "${campus_names[$i]#[0-9]* }" ]]; then
                    campus_choice=$i
                    break
                fi
            done
        fi

        # If valid choice, set size variables
        if [[ -n "$campus_choice" ]]; then
            home_max_size=${home_max_sizes[$campus_choice]}
            sgoinfre_max_size=${sgoinfre_max_sizes[$campus_choice]}
            home_upgraded_size=${home_upgraded_sizes[$campus_choice]}
            sgoinfre_upgraded_size=${sgoinfre_upgraded_sizes[$campus_choice]}
            break
        fi
        pretty_print "${bold}${red}Invalid input. Please enter a valid number or your campus name.${reset}"
    done
    shopt -u nocasematch
fi

# Prompt user for max sizes if still not known, or if storage was upgraded
for dir in home sgoinfre; do
    max_size_var_name="${dir}_max_size"
    upgraded_size_var_name="${dir}_upgraded_size"

    # If a max size still not known, prompt user to enter it
    if [[ ! ${!max_size_var_name} =~ ^[0-9]+$ ]]; then
        # Prompt until it is a number
        while true; do
            pretty_print "Enter the maximum allowed size of your ${bold}$dir${reset} directory in GB:"
            ft_read -rp "> "
            if [[ $REPLY =~ ^[0-9]+$ ]]; then
                declare "$max_size_var_name=$REPLY"
                break
            fi
            pretty_print "${bold}${red}Invalid input. Please enter a number.${reset}"
        done

    # Prompt if storage upgraded
    elif [[ "${!upgraded_size_var_name}" =~ ^[0-9]+$ ]]; then
        if prompt_user "Have you upgraded your ${bold}$dir${reset} storage to ${bold}${!upgraded_size_var_name}GB${reset}? (default: ${!max_size_var_name}GB)"; then
            declare "$max_size_var_name=${!upgraded_size_var_name}"
        fi
    fi
done

pretty_print "${yellow}Downloading '$dest_file' into '$dest_dir'...${reset}"

# Get the URL of a dev version from the branch specified as an argument, or the asset from the latest release
if [[ -n $1 ]] && [[ $1 != "update" ]]; then
    pretty_print "${bold}${yellow}Using dev version from branch '$1'...${reset}"
    if git ls-remote --heads https://github.com/itislu/42free.git "$1" 2>/dev/null | grep -q "$1$"; then
        script_url="https://raw.githubusercontent.com/itislu/42free/$1/$dest_file"
    else
        pretty_print "${bold}${red}Branch '$1' does not exist.${reset}"
        exit $download_failed
    fi
else
    script_url=$("$downloader" "$downloader_opts_stdout" "$latest_release_url" | grep "browser_download_url" | cut -d '"' -f 4)
fi

# Download the script
mkdir -p "$dest_dir"
"$downloader" "$downloader_opts_file" "$dest_dir/$dest_file" "$script_url"
exit_status=$?
if [[ $exit_status -ne 0 ]]; then
    pretty_print "${bold}${red}Failed to download file with $downloader.${reset}"
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
    if change_config "alias 42free='bash $dest_dir/$dest_file'" "$config_file" 2>/dev/null; then
        pretty_print "${yellow}Added 42free alias to $shell_name.${reset}"
    fi
    if change_config "export HOME_MAX_SIZE=$home_max_size" "$config_file" 2>/dev/null; then
        pretty_print "${yellow}Added HOME_MAX_SIZE environment variable set to $home_max_size to $shell_name.${reset}"
    fi
    if change_config "export SGOINFRE_MAX_SIZE=$sgoinfre_max_size" "$config_file" 2>/dev/null; then
        pretty_print "${yellow}Added SGOINFRE_MAX_SIZE environment variable set to $sgoinfre_max_size to $shell_name.${reset}"
    fi
done

# Check user's default shell
if [[ "$SHELL" != *"bash"* ]] && [[ "$SHELL" != *"zsh"* ]] && [[ "$SHELL" != *"fish"* ]]; then
    pretty_print "${bold}${bright_yellow}Could not set up 42free for $(basename "$SHELL"). Please do it manually.${reset}"
    pretty_print "${bold}${bright_yellow}You can paste the following lines into your shell's configuration file:"
    pretty_print "${bold}alias 42free='bash $dest_dir/$dest_file'${reset}"
    pretty_print "${bold}export HOME_MAX_SIZE=$home_max_size${reset}"
    pretty_print "${bold}export SGOINFRE_MAX_SIZE=$sgoinfre_max_size${reset}"
    exit $install_failed
fi

# Check if it's an update or a fresh install
if [[ $1 == "update" ]]; then
    pretty_print "${bold}${bright_green}Update completed.${reset}"
else
    pretty_print "${bold}${bright_green}Installation completed.${reset}"
    pretty_print "You can now use the 42free command in your terminal."
    pretty_print "To see the manual, run '42free --help'."
    pretty_print "To just start, run '${bold}42free${reset}'."
fi

ft_exit $success
