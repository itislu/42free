#!/usr/bin/env bash

current_version="v1.14.0+dev"

# Exit codes
success=0
input_error=1
minor_error=2
major_error=3

default_args_linux=(
    # System: Cache
    "$HOME/.cache"

    # Virtualization: Docker
    "$HOME/.local/share/docker"

    # Code editors: Visual Studio Code, Cursor
    "$HOME/.config/Code/Cache"
    "$HOME/.config/Code/CachedData"
    "$HOME/.config/Code/CachedExtensionVSIXs"
    "$HOME/.config/Code/Crashpad"
    "$HOME/.config/Code/User/workspaceStorage"
    "$HOME/.config/Code/Service Worker"
    "$HOME/.config/Code/WebStorage"
    "$HOME/.config/Cursor/Cache"
    "$HOME/.config/Cursor/CachedData"
    "$HOME/.config/Cursor/CachedExtensionVSIXs"
    "$HOME/.config/Cursor/Crashpad"
    "$HOME/.config/Cursor/User/workspaceStorage"
    "$HOME/.config/Cursor/Service Worker"
    "$HOME/.config/Cursor/WebStorage"

    # Communication apps: Discord, Slack
    "$HOME/.var/app/com.discordapp.Discord"
    "$HOME/.var/app/com.slack.Slack"

    # Browsers: Brave, Chrome, Opera, Vivaldi
    "$HOME/.var/app/com.brave.Browser/cache"
    "$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/Default/Service Worker"
    "$HOME/.config/google-chrome/Default/Service Worker"
    "$HOME/.var/app/com.google.Chrome/cache"
    "$HOME/.var/app/com.google.Chrome/config/google-chrome/Default/Service Worker"
    "$HOME/.var/app/com.opera.Opera/cache"
    "$HOME/.var/app/com.opera.Opera/config/opera/Default/Service Worker"
    "$HOME/.var/app/com.vivaldi.Vivaldi/cache"
    "$HOME/.var/app/com.vivaldi.Vivaldi/config/vivaldi/Default/Service Worker"

    # Package managers: Homebrew, capt
    "$HOME/.brew"
    "$HOME/.capt"
)

default_args_macos=(
    # System: Cache
    "$HOME/Library/Caches"

    # Virtualization: Docker
    "$HOME/Library/Containers/com.docker.docker/Data/vms/0/data"

    # Code editors: Visual Studio Code, Cursor
    "$HOME/Library/Application Support/Code/Cache"
    "$HOME/Library/Application Support/Code/CachedData"
    "$HOME/Library/Application Support/Code/CachedExtensionVSIXs"
    "$HOME/Library/Application Support/Code/Crashpad"
    "$HOME/Library/Application Support/Code/User/workspaceStorage"
    "$HOME/Library/Application Support/Code/Service Worker"
    "$HOME/Library/Application Support/Code/WebStorage"
    "$HOME/Library/Application Support/Cursor/Cache"
    "$HOME/Library/Application Support/Cursor/CachedData"
    "$HOME/Library/Application Support/Cursor/CachedExtensionVSIXs"
    "$HOME/Library/Application Support/Cursor/Crashpad"
    "$HOME/Library/Application Support/Cursor/User/workspaceStorage"
    "$HOME/Library/Application Support/Cursor/Service Worker"
    "$HOME/Library/Application Support/Cursor/WebStorage"

    # Communication apps: Discord, Slack
    "$HOME/Library/Application Support/discord/Cache"
    "$HOME/Library/Application Support/discord/Service Worker"
    "$HOME/Library/Application Support/Slack/Cache"
    "$HOME/Library/Application Support/Slack/Service Worker"

    # Browsers: Brave, Chrome, Opera, Vivaldi
    "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default/Service Worker"
    "$HOME/Library/Application Support/Google/Chrome/Default/Service Worker"
    "$HOME/Library/Application Support/Opera Software/Opera Stable/Service Worker"
    "$HOME/Library/Application Support/Vivaldi/Default/Service Worker"
)

# Check OS
os_name=$(uname -s)
if [[ "$os_name" == "Linux" ]]; then
    default_args=("${default_args_linux[@]}")
elif [[ "$os_name" == "Darwin" ]]; then
    default_args=("${default_args_macos[@]}")
else
    echo "42free currently only supports Linux and macOS. Sorry :("
    exit $major_error
fi

# Standard variables
stderr=""
install_script="https://raw.githubusercontent.com/itislu/42free/main/install.sh"
current_dir=$(pwd)
script_dir="$HOME/.scripts"
script_path="$script_dir/42free.sh"
sgoinfre="$SGOINFRE"
sgoinfre_alt_mount="/nfs"
sgoinfre_common_locations=(
    "/sgoinfre"
    "/System/Volumes/Data/sgoinfre"
)

# Shell config files
bash_config="$HOME/.bashrc"
zsh_config="$HOME/.zshrc"
fish_config="$HOME/.config/fish/config.fish"

# Max sizes in GB
if [[ -n "$HOME_MAX_SIZE" ]] && [[ "$HOME_MAX_SIZE" =~ ^[0-9]+$ ]]; then
    home_max_size=$HOME_MAX_SIZE
else
    home_max_size=0
fi
if [[ -n "$SGOINFRE_MAX_SIZE" ]] && [[ "$SGOINFRE_MAX_SIZE" =~ ^[0-9]+$ ]]; then
    sgoinfre_max_size=$SGOINFRE_MAX_SIZE
else
    sgoinfre_max_size=0
fi

# Check if curl or wget is available
if command -v curl &>/dev/null; then
    downloader="curl"
    downloader_opts_stdout="-sSL"
elif command -v wget &>/dev/null; then
    downloader="wget"
    downloader_opts_stdout="-qO-"
fi

# Flags
bad_input=false
arg_skipped=false
syscmd_failed=false
changed_config=false
printed_update_info=false

# Text formatting
reset="\e[0m"
bold="\e[1m"
underlined="\e[4m"
red="\e[31m"
yellow="\e[33m"
bright_red="\e[91m"
bright_green="\e[92m"
bright_yellow="\e[93m"
bright_blue="\e[94m"
bright_cyan="\e[96m"

header="\n\
                ${bold}${bright_yellow}📁  42free  📁${reset}"
tagline="\
            ${bold}${bright_yellow}Never run \`ncdu\` again${reset}"
delim_small="\
       --------------------------------"
delim_big="\
     ${underlined}                                    ${reset}"

# Indicators
indicator_error="${bold}${red}ERROR:${reset}"
indicator_warning="${bold}${bright_yellow}WARNING:${reset}"
indicator_info="${bold}${bright_blue}INFO:${reset}"
indicator_success="${bold}${bright_green}SUCCESS:${reset}"

# Messages
msg_manual="\
$header
$tagline
$delim_big
\n\
42free helps you free up storage space in your home directory by moving files to your personal sgoinfre directory.
\n\
It leaves behind a symbolic link in the original location.
All programs then access the moved files through the symlink and they will accumulate their space outside of your home directory.
\n\
You only need to run 42free once for every directory or file you want to free the space of.
\n\
$delim_small
\n\
${bold}${underlined}Usage:${reset} ${bold}42free${reset} [TARGET]... [OPTION]...
    If no arguments are given, 42free will make some suggestions.
    Target paths can be absolute or relative to the current directory.
    42free will automatically detect if an argument is the source or the destination.
    Example: '${bold}42free /path/to/large/directory largeFileInCurDir${reset}'
    Closing all programs first will help to avoid errors during the move.
\n\
${bold}${underlined}Options:${reset} You can pass options anywhere in the arguments.
    -r, --restore    Move the directories and files back to their original
                     location in home.
    -s, --sgoinfre   Change the path that 42free considers as your personal
                     sgoinfre directory and exit.
    -m, --max-size   Change the warning sizes for the home and sgoinfre
                     directories (in GB) and exit.
                     Current sizes:
                       HOME_MAX_SIZE=$home_max_size
                       SGOINFRE_MAX_SIZE=$sgoinfre_max_size
    -u, --update     Check for a new version of 42free and exit.
    -h, --help       Display this help message and exit.
    -v, --version    Display version information and exit.
        --uninstall  Uninstall 42free.
    --               Stop interpreting options.
\n\
${bold}${underlined}Error codes:${reset}
    1 - Input error
        An argument was invalid.
          (no arguments, unknown option, invalid path, file does not exist)
    2 - Minor error
        An argument was skipped.
          (symbolic link, file conflict, no space left)
    3 - Major error
        An operation failed.
          (operating system not supported, sgoinfre permissions, update failed, move failed, restore failed, cleanup failed)
\n\
$delim_small
\n\
To contribute, report bugs or share improvement ideas, visit
${underlined}${bright_blue}https://github.com/itislu/42free${reset}."

msg_manual_reminder="To see the full manual, run '${bold}42free --help${reset}'."

msg_manual_short="\
${underlined}Usage:${reset} ${bold}42free${reset} [TARGET]...
Free up space of TARGETs, or make suggestions if no arguments are given.
${underlined}Example:${reset} '42free /path/to/large/directory largeFileInCurDir'
Paths can be absolute or relative to the current directory.
\n\
$msg_manual_reminder"

msg_version="\
${bold}42free $current_version${reset}
A script made for 42 students to take advantage of symbolic links to free up storage without data loss.
For more information, visit ${underlined}${bright_blue}https://github.com/itislu/42free${reset}."

msg_close_programs="${bold}${bright_yellow}Close all programs first to avoid errors during the move.${reset}"

msg_report_sgoinfre="\n\
$indicator_error${bold} There does not seem to be a sgoinfre directory available on your campus.${reset}
If you are sure there is one, please open an issue on GitHub and mention the following:
  - The campus you are on.
  - The path to your sgoinfre directory.
${underlined}${bright_blue}https://github.com/itislu/42free/issues${reset}"

# Prompts
prompt_update="Do you wish to update?"
prompt_agree_all="Do you agree with all of those?"
prompt_continue="Do you wish to continue?"
prompt_continue_still="Do you still wish to continue?"
prompt_continue_with_rest="Do you wish to continue with the other arguments?"
prompt_correct_path="Is this the correct path to your personal sgoinfre directory?"
prompt_symlink="Do you wish to create a symbolic link to it?"
prompt_replace="Do you wish to continue and replace any duplicate files?"
prompt_merge="Do you wish to continue and merge the directories, replacing any duplicate files?"
prompt_uninstall="Do you wish to uninstall 42free?"

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

print_stderr() {
    while IFS= read -r line; do
        pretty_print "STDERR: $line"
    done <<< "$stderr"
}

print_one_stderr() {
    line=$(head -n 1 <<< "$stderr")
    if [[ -n "$line" ]]; then
        pretty_print "STDERR: $line"
    fi
    if [[ $(wc -l <<< "$stderr") -gt 1 ]]; then
        pretty_print "STDERR: ..."
    fi
}

ft_exit() {
    local exit_code=$1

    if $changed_config; then
        # Start the default shell to make changes of the shell config available immediately
        if [[ $exit_code -eq 0 ]] && [[ -x "$SHELL" ]]; then
            exec $SHELL
        fi
        # If exec failed, inform the user to start a new shell
        pretty_print "Please start a new shell to make the changed 42free configs available."
    fi
    if [[ $exit_code =~ ^-?[0-9]+$ ]]; then
        exit $exit_code
    elif $syscmd_failed; then
        exit $major_error
    elif $arg_skipped; then
        exit $minor_error
    elif $bad_input; then
        exit $input_error
    else
        exit $success
    fi
}

exit_no_sgoinfre() {
    if [[ ! -d $sgoinfre ]]; then
        pretty_print "$msg_report_sgoinfre"
        ft_exit $major_error
    fi
}

print_skip_arg() {
    pretty_print "Skipping '$1'."
}

# Prompt the user for confirmation
# Default is 'no', for 'yes' needs y/Y/yes/Yes + Enter key
prompt_with_enter() {
    pretty_print "$1 [${bold}y${reset}/${bold}N${reset}]"
    read -rp "> "
    if [[ "$REPLY" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        return 0
    fi
    return 1
}

# Prompt the user for confirmation
# Default is 'yes', only needs y/Y key
prompt_single_key() {
    pretty_print "$1 [${bold}Y${reset}/${bold}n${reset}]"
    read -n 1 -rp "> "
    if [[ -n "$REPLY" ]]; then
        echo
    fi
    if [[ "$REPLY" =~ ^([Yy]?)$|^$ ]]; then
        return 0
    fi
    return 1
}

export_all_functions() {
    for fn in $(declare -F | cut -d " " -f 3); do
        export -f "$fn"
    done
}

# Convert the base path of the default arguments
convert_default_args() {
    local replacement_base=$1

    for i in "${!default_args[@]}"; do
        default_args[i]="${default_args[i]/$HOME/$replacement_base}"
    done
}

# Capitalize the first letter of a string
capitalize_initial() {
    echo "$(tr '[:lower:]' '[:upper:]' <<< "${1:0:1}")${1:1}"
}

# Capitalize all letters of a string
capitalize_full() {
    tr '[:lower:]' '[:upper:]' <<< "$1"
}

# Convert a size from bytes to a human-readable format
bytes_to_human() {
    python3 -c "
import locale

size_in_bytes = $1
suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB']
i = 0

while size_in_bytes >= 1024 and i < len(suffixes) - 1:
    size_in_bytes /= 1024
    i += 1

locale.setlocale(locale.LC_ALL, '')
print(locale.format_string('%0.1f', size_in_bytes) + suffixes[i])
"
}

# Trim a string to the first occurrence of a target directory after a certain pattern
trim_path() {
    python3 -c "
import sys

path = '$1'
target_dir = '$2'
path_pattern = '$3'

path_len = len(path)
target_dir_len = len(target_dir)

# Find the path pattern
i = path.find(path_pattern)
if i == -1:
    sys.exit(1)

i = path.find(target_dir, i)

while i != -1:
    end_of_target_dir = i + target_dir_len

    # Check that target directory is an exact directory match
    if ((i == 0 or path[i - 1] == '/') and
        (end_of_target_dir == path_len or path[end_of_target_dir] == '/')):
        # Print path until the first occurance of target directory
        print(path[:end_of_target_dir])
        sys.exit(0)

    i = path.find(target_dir, i + 1)

sys.exit(1)
"
}

# Breadth-first search to find a directory with a specific name and containing a specific pattern in its path
find_dir_bfs() {
    python3 -c "
import os
import queue
import sys

start_dir = '$1'
exclude_dir = '$2'
target_dir = '$3'
path_pattern = '$4'

q = queue.Queue()
q.put(start_dir)

while not q.empty():
    current_dir = q.get()
    try:
        # Skip processing for the excluded directory
        if current_dir.startswith(exclude_dir):
            continue

        with os.scandir(current_dir) as it:
            for entry in it:
                if entry.is_dir():
                    full_path = entry.path
                    dir_name = os.path.basename(full_path)

                    # Stop if the directory name is the target and the path contains the pattern
                    if dir_name == target_dir and path_pattern in full_path:
                        print(full_path)
                        sys.exit(0)

                    # Add subdirectories to the queue for further processing
                    q.put(full_path)
    except Exception:
        continue

sys.exit(1)
"
}

# Depth-first search to find a directory with a specific name and containing a specific pattern in its path
find_dir_dfs() {
    local start_dir=$1
    local exclude_dir=$2
    local target_dir=$3
    local path_pattern=$4
    local result_path

    result_path=$(find "$start_dir" -maxdepth 12 -path "$exclude_dir" -prune -o -path "*$path_pattern*" -type d -name "$target_dir" -print -quit)
    result_path=$(trim_path "$result_path" "$target_dir" "$path_pattern")

    if [[ -d $result_path ]]; then
        echo "$result_path"
        return 0
    fi
    return 1
}

# Run breadth-first and depth-first search in parallel and wait for the first to finish
find_dir() {
    local result_var=$1
    shift
    local timeout=$1
    shift
    local jobs=()
    local tmpfile_bfs="/tmp/42free~$$~bfs"
    local tmpfile_dfs="/tmp/42free~$$~dfs"
    local result_path

    find_dir_bfs "$@" > "$tmpfile_bfs" &
    jobs+=($!)
    find_dir_dfs "$@" > "$tmpfile_dfs" &
    jobs+=($!)

    wait_for_jobs "$timeout" "any" "searching_dir" "${jobs[@]}"

    result_path=$(cat "$tmpfile_bfs" 2>/dev/null)
    if [[ ! -d $result_path ]]; then
        result_path=$(cat "$tmpfile_dfs" 2>/dev/null)
    fi
    rm -f "$tmpfile_bfs" "$tmpfile_dfs"

    if [[ -d $result_path ]]; then
        eval "$result_var='$result_path'"
        return 0
    fi
    return 1
}

find_sgoinfre() {
    pretty_print "Searching your sgoinfre directory..."

    # Quick search in common locations
    sgoinfre=$(timeout 1s find "${sgoinfre_common_locations[@]}" -maxdepth 6 -type d -name "$USER" -print -quit 2>/dev/null)
    sgoinfre=$(trim_path "$sgoinfre" "$$USER" "/sgoinfre/")

    # In-depth search
    if [[ ! -d $sgoinfre ]]; then
        pretty_print "This can take up to 1 minute..."
        find_dir "sgoinfre" "60s" "/" "$HOME" "$USER" "/sgoinfre/" 2>/dev/null
    fi

    # Dereference all symbolic links in the result
    if [[ -e $sgoinfre ]]; then
        sgoinfre=$(realpath "$sgoinfre" 2>/dev/null)
    fi

    if [[ -d $sgoinfre ]]; then
        pretty_print "Located your sgoinfre directory at '${bold}$sgoinfre${reset}'."
    else
        # Prompt user to input the path manually
        pretty_print "$indicator_error${bold} Could not find your sgoinfre directory.${reset}"
        trap exit_no_sgoinfre EXIT
        prompt_sgoinfre_path "Please enter the path to your personal sgoinfre directory manually:"
        trap - EXIT
    fi

    # Save the path into all supported shell config files where it doesn't exist yet
    pretty_print "Saving the path of your sgoinfre directory..."
    pretty_print "If you want to change it in the future, run '42free --sgoinfre'."
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
        if change_config "export SGOINFRE='$sgoinfre'" "$config_file" 2>/dev/null; then
            pretty_print "${yellow}Added SGOINFRE environment variable to $shell_name.${reset}"
        fi
    done
}

# Prompt the user for a valid path to their personal sgoinfre directory
prompt_sgoinfre_path() {
    local reply

    pretty_print "$1"
    while true; do
        read -rp "> "
        # Expand all variables in reply
        reply=$(eval echo "$REPLY" 2>/dev/null)

        # Get real absolute path
        if [[ -d "$reply" ]]; then
            pretty_print "Dereferencing all symbolic links in the path..."
        fi
        reply=$(realpath "$reply" 2>/dev/null)

        # Check if directory exists
        if [[ ! -d "$reply" ]]; then
            pretty_print " ✖ Not an existing directory."
            pretty_print "Please try again."

        # Check if sgoinfre directory
        elif [[ ! "$reply" =~ sgoinfre ]]; then
            pretty_print "There is no mention of 'sgoinfre' in the path:"
            pretty_print "'${bold}$reply${reset}'"
            if prompt_with_enter "Are you sure this is the correct path to your personal sgoinfre directory?"; then
                sgoinfre="$reply"
                break
            fi
            pretty_print " ✖ Not a sgoinfre directory."
            pretty_print "Please enter the path to your personal sgoinfre directory."

        # Check if user's directory
        elif [[ ! "$reply" =~ $USER ]]; then
            pretty_print "There is no mention of your username in the path:"
            pretty_print "'${bold}$reply${reset}'"
            if prompt_with_enter "Are you sure this is the correct path to your personal sgoinfre directory?"; then
                sgoinfre="$reply"
                break
            fi
            pretty_print " ✖ Not your personal sgoinfre directory."
            pretty_print "Please enter the path to your personal sgoinfre directory."

        # Prompt user for confirmation
        else
            pretty_print " ✔ Directory exists."
            pretty_print "'${bold}$reply${reset}'"
            if prompt_single_key "$prompt_correct_path"; then
                sgoinfre="$reply"
                break
            fi
            pretty_print "Please try again."
        fi
    done
}

change_sgoinfre_permissions() {
    pretty_print "$indicator_warning The permissions of your personal sgoinfre directory are not set to '${bold}rwx------${reset}'."
    pretty_print "They are currently set to '${bold}$sgoinfre_permissions${reset}'."
    pretty_print "It is ${bold}highly${reset} recommended to change the permissions so that other students cannot access the files you will move to sgoinfre."
    if prompt_single_key "Do you wish to change the permissions of '$sgoinfre' to '${bold}rwx------${reset}'?"; then
        if stderr=$(chmod 700 "$sgoinfre" 2>&1); then
            pretty_print "$indicator_success The permissions of '$sgoinfre' have been changed to '${bold}rwx------${reset}'."
        else
            pretty_print "$indicator_error Failed to change the permissions of '$sgoinfre'."
            print_stderr
            syscmd_failed=true
            if ! prompt_with_enter "$prompt_continue_still"; then
                return 1
            fi
            pretty_print "Keeping the permissions of '$sgoinfre' as '$sgoinfre_permissions'."
        fi
    else
        pretty_print "Keeping the permissions of '$sgoinfre' as '$sgoinfre_permissions'."
    fi
    return 0
}

create_sgoinfre_symlink() {
    pretty_print "$indicator_info Could not find a symbolic link to your sgoinfre directory in your home directory."
    pretty_print "It can be useful to have one there for easy access."
    if prompt_single_key "Do you wish to create it?"; then
        if stderr=$(symlink "$sgoinfre" "$HOME/sgoinfre" 2>&1); then
            pretty_print "$indicator_success Created a symbolic link named 'sgoinfre' in your home directory."
        else
            pretty_print "$indicator_error Cannot create symbolic link."
            print_stderr
            syscmd_failed=true
            if ! prompt_with_enter "$prompt_continue_still"; then
                return 1
            fi
        fi
    else
        pretty_print "Not creating a symbolic link to your sgoinfre directory."
    fi
    echo
    return 0
}

stat_human_readable() {
    local path=$1

    if [[ "$os_name" == "Linux" ]]; then
        stat -c %A "$path"
    elif [[ "$os_name" == "Darwin" ]]; then
        stat -f %Sp "$path"
    fi
}

# If realpath command is not available, define a custom function as a replacement
if ! command -v realpath &>/dev/null; then
    realpath() {
        python3 -c "import os; print(os.path.realpath('$1'))"
    }
fi

# If timeout command is not available, define a custom function as a replacement
if ! command -v timeout &>/dev/null; then
    timeout() {
        local duration=$1
        local cmd=("${@:2}")

        python3 -c "
import subprocess
import sys

def convert_to_seconds(duration):
    units = {'s': 1, 'm': 60, 'h': 3600, 'd': 86400}
    if duration[-1] in units:
        return float(duration[:-1]) * units[duration[-1]]
    else:
        return float(duration)

duration = convert_to_seconds(sys.argv[1])
cmd = sys.argv[2:]

try:
    if duration > 0:
        proc = subprocess.Popen(cmd)
        proc.communicate(timeout=duration)
    else:
        subprocess.run(cmd)
except subprocess.TimeoutExpired:
    # Send SIGTERM and wait until subprocess terminates
    proc.terminate()
    proc.wait()
    # Exit code 124 is used by GNU 'timeout' for timeout expiration
    sys.exit(124)
" "$duration" "${cmd[@]}"
    }
fi

move_files() {
    local source_path=$1
    local target_dirpath=$2
    local operation=$3
    local rsync_status

    # Move the files in a background job
    pretty_print "$(capitalize_initial "$operation") '$(basename "$source_path")' to '$target_dirpath'..."
    stderr=$(rsync -a --remove-source-files "$source_path" "$target_dirpath/" 2>&1) &

    # Wait for rsync to finish
    wait_for_jobs "all" "$operation" $!
    rsync_status=$?

    # Check the exit status of rsync
    if [[ $rsync_status -ne 0 ]]; then
        syscmd_failed=true
    fi

    cleanup_empty_dirs "$source_path"
    return $rsync_status
}

cleanup_empty_dirs() {
    local dir=$1

    find "$dir" -type d -empty -delete 2>/dev/null
    while [[ "$dir" != "$HOME" ]] && [[ "$dir" != "$sgoinfre" ]]; do
        rmdir "$dir" 2>/dev/null
        dir=$(dirname "$dir")
    done
}

# Cross-compatible implementation of `ln -T`
symlink() {
    local target_path=$1
    local link_path=$2

    if [[ -d "$link_path" ]]; then
        if [[ $(basename "$link_path") != $(basename "$target_path") ]]; then
            target_path=$(dirname "$target_path")/$(basename "$link_path")
        fi
        link_path=$(dirname "$link_path")
    fi
    ln -s "$target_path" "$link_path"
}

# Set animation variables, default to simple spinner
set_animation() {
    if [[ "$1" == "moving" ]]; then
        pacing=0.1
        frames=(
            '  📁          📁'
            '  📂          📁'
            '  📂📄        📁'
            '  📂 📄       📁'
            '  📁  📄      📁'
            '  📁   📄     📁'
            '  📁    📄    📁'
            '  📁     📄   📁'
            '  📁      📄  📁'
            '  📁       📄 📂'
            '  📁        📄📂'
            '  📁          📂'
            '  📁          📁'
        )
        return 0
    elif [[ "$1" == "restoring" ]]; then
        pacing=0.1
        frames=(
            '  📁          📁'
            '  📁          📂'
            '  📁        📄📂'
            '  📁       📄 📂'
            '  📁      📄  📁'
            '  📁     📄   📁'
            '  📁    📄    📁'
            '  📁   📄     📁'
            '  📁  📄      📁'
            '  📂 📄       📁'
            '  📂📄        📁'
            '  📂          📁'
            '  📁          📁'
        )
        return 0
    elif [[ "$1" == "searching" ]]; then
        pacing=0.25
        frames=(
            '  🔎📁📁📁📁📁📁'
            '  🔎📂📁📁📁📁📁'
            '  📄🔎📁📁📁📁📁'
            '  📄🔎📂📁📁📁📁'
            '  📄📄🔎📁📁📁📁'
            '  📄📄🔎📂📁📁📁'
            '  📄📄📄🔎📁📁📁'
            '  📄📄📄🔎📂📁📁'
            '  📄📄📄📄🔎📁📁'
            '  📄📄📄📄🔎📂📁'
            '  📄📄📄📄📄🔎📁'
            '  📄📄📄📄📄🔎📂'
            '  📄📄📄📄📄📄🔎'
            '  📄📄📄📄📄📄🔍'
            '  📄📄📄📄📄🔍📁'
            '  📄📄📄📄🔍📁📁'
            '  📄📄📄🔍📁📁📁'
            '  📄📄🔍📁📁📁📁'
            '  📄🔍📁📁📁📁📁'
            '  🔍📁📁📁📁📁📁'
        )
        return 0
    elif [[ "$1" == "searching_dir" ]]; then
        pacing=0.5
        frames=(
            '  🔎📁📁📁📁📁📁'
            '  📂🔎📁📁📁📁📁'
            '  📂📂🔎📁📁📁📁'
            '  📂📂📂🔎📁📁📁'
            '  📂📂📂📂🔎📁📁'
            '  📂📂📂📂📂🔎📁'
            '  📂📂📂📂📂📂🔎'
            '  📂📂📂📂📂📂🔍'
            '  📂📂📂📂📂🔍📂'
            '  📂📂📂📂🔍📂📂'
            '  📂📂📂🔍📂📂📂'
            '  📂📂🔍📂📂📂📂'
            '  📂🔍📂📂📂📂📂'
            '  🔍📂📂📂📂📂📂'
            '  🔎📂📂📂📂📂📂'
            '  📁🔎📂📂📂📂📂'
            '  📁📁🔎📂📂📂📂'
            '  📁📁📁🔎📂📂📂'
            '  📁📁📁📁🔎📂📂'
            '  📁📁📁📁📁🔎📂'
            '  📁📁📁📁📁📁🔎'
            '  📁📁📁📁📁📁🔍'
            '  📁📁📁📁📁🔍📁'
            '  📁📁📁📁🔍📁📁'
            '  📁📁📁🔍📁📁📁'
            '  📁📁🔍📁📁📁📁'
            '  📁🔍📁📁📁📁📁'
            '  🔍📁📁📁📁📁📁'
        )
        return 0
    else
        pacing=0.25
        frames=(
            '  | '
            '  / '
            '  - '
            '  \ '
        )
    fi
    return 1
}

clear_prev_line() {
    printf "\e[1K\e[1A\n"
}

restore_cursor_exit() {
    tput cnorm
    clear_prev_line
    exit
}

any_job_running() {
    local job_pids=("$@")

    for job_pid in "${job_pids[@]}"; do
        if kill -0 "$job_pid" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

all_jobs_running() {
    local job_pids=("$@")

    for job_pid in "${job_pids[@]}"; do
        if ! kill -0 "$job_pid" 2>/dev/null; then
            return 1
        fi
    done
    return 0
}

# Needs frames and job_pids arrays being set
animate_while_jobs_running() {
    local mode=$1
    local animation=$2
    local job_pids=("${@:3}")

    set_animation "$animation"

    # Catch signals to enable cursor again and clear line
    trap restore_cursor_exit SIGINT SIGTERM

    # Hide cursor
    tput civis
    # Print frames while jobs are running
    while true; do
        for frame in "${frames[@]}"; do
            if [[ "$mode" == "any" ]]; then
                if ! all_jobs_running "${job_pids[@]}"; then
                    break 2
                fi
            else
                if ! any_job_running "${job_pids[@]}"; then
                    break 2
                fi
            fi
            printf "\r%s" "$frame"
            sleep "$pacing"
        done
    done
    # Clear line on completion
    printf "\r\e[K"
    # Restore cursor
    tput cnorm

    # Reset signal traps
    trap - SIGINT SIGTERM
}

stop_jobs() {
    local job_pids=("$@")

    for job_pid in "${job_pids[@]}"; do
        kill -SIGTERM "$job_pid" 2>/dev/null
    done
}

# Arguments: [n(s|m|h|d)] [any|all] [moving|restoring|searching|searching_dir] job_pids...
wait_for_jobs() {
    local timeout
    local mode
    local animation
    local job_pids=()
    local exit_status
    local job_exit_status

    # Catch signals to stop any running jobs
    trap stop_jobs SIGINT SIGTERM

    # Check for timeout, requires a time unit, default to no timeout
    if [[ $1 =~ ^[0-9]+[smhd]$ ]]; then
        timeout=$1
        shift
    fi
    # Check for mode, default to "all"
    if [[ "$1" == "any" || "$1" == "all" ]]; then
        mode=$1
        shift
    else
        mode="all"
    fi
    # Check for animation, default to simple spinner
    if [[ "$1" == "moving" || "$1" == "restoring" || "$1" == "searching" || "$1" == "searching_dir" ]]; then
        animation=$1
        shift
    fi
    job_pids=("$@")

    # Start animation with or without timeout
    if [[ -n "$timeout" ]]; then
        # Run in subshell to avoid all functions being exported afterwards
        (
            export_all_functions
            timeout "$timeout" bash -c 'animate_while_jobs_running "$@"' animate_while_jobs_running "$mode" "$animation" "${job_pids[@]}"
        )
    else
        animate_while_jobs_running "$mode" "$animation" "${job_pids[@]}"
    fi

    # Collect exit status of finished jobs, stop others
    exit_status=0
    for job_pid in "${job_pids[@]}"; do
        if ! kill -0 "$job_pid" 2>/dev/null; then
            wait "$job_pid" 2>/dev/null
            job_exit_status=$?
            if [[ $job_exit_status -ne 0 ]]; then
                exit_status=$job_exit_status
            fi
        else
            kill -SIGTERM "$job_pid" 2>/dev/null
        fi
    done

    # Reset signal traps
    trap - SIGINT SIGTERM
    return $exit_status
}

# Calculate a color based on the percentage of used space
calculate_usage_color() {
    local size=$1
    local max_size=$2
    local percentage
    local color

    # Calculate the percentage of used space
    percentage=$(awk -v s="$size" -v ms="$max_size" 'BEGIN { printf "%.2f", s / ms * 100 }')

    if (( $(echo "$percentage >= 100" | bc -l) )); then
        color="${red}"
    elif (( $(echo "$percentage >= 90" | bc -l) )); then
        color="${bright_red}"
    elif (( $(echo "$percentage >= 80" | bc -l) )); then
        color="${bright_yellow}"
    else
        color="${bright_green}"
    fi
    echo "$color"
}

print_available_space() {
    local source_base_size_in_kb=$1
    local target_base_size_in_kb=$2
    local source_base_size
    local target_base_size
    local home_size
    local sgoinfre_size
    local home_color
    local sgoinfre_color

    source_base_size=$(echo "$source_base_size_in_kb/1024/1024" | bc -l | xargs printf "%.2f")
    target_base_size=$(echo "$target_base_size_in_kb/1024/1024" | bc -l | xargs printf "%.2f")

    if ! $restore; then
        home_size=$source_base_size
        sgoinfre_size=$target_base_size
    else
        home_size=$target_base_size
        sgoinfre_size=$source_base_size
    fi

    pretty_print "${bold}${underlined}Space used:${reset}"
    if [[ $home_max_size -gt 0 ]]; then
        home_color=$(calculate_usage_color "$home_size" "$home_max_size")
        printf "${bold}  %-10s ${home_color}%5.2f${reset}${bold}/%dGB${reset}\n" "Home:" "$home_size" "$home_max_size"
    else
        printf "${bold}  %-10s %5.2fGB${reset}\n" "Home:" "$home_size"
    fi
    if [[ $sgoinfre_max_size -gt 0 ]]; then
        sgoinfre_color=$(calculate_usage_color "$sgoinfre_size" "$sgoinfre_max_size")
        printf "${bold}  %-10s ${sgoinfre_color}%5.2f${reset}${bold}/%dGB\n${reset}" "Sgoinfre:" "$sgoinfre_size" "$sgoinfre_max_size"
    else
        printf "${bold}  %-10s %5.2fGB${reset}\n" "Sgoinfre:" "$sgoinfre_size"
    fi
}

get_timestamp() {
    date +%Y%m%d%H%M%S
}

get_latest_version_number() {
    # Check if curl or wget is available
    if [[ -z "$downloader" ]]; then
        if [[ "$1" != "quiet" ]]; then
            pretty_print "$indicator_error Cannot check for updates."
            pretty_print "Neither ${bold}${red}curl${reset} nor ${bold}${red}wget${reset} was found."
            pretty_print "Please install one of them and try again."
        fi
        return $major_error
    fi

    # Fetch the latest version from the git tags on GitHub
    latest_version=$("$downloader" "$downloader_opts_stdout" "https://api.github.com/repos/itislu/42free/tags")
    latest_version=$(echo "$latest_version" | grep -m 1 '"name":' | cut -d '"' -f 4) 2>/dev/null
    if [[ -z "$latest_version" ]]; then
        if [[ "$1" != "quiet" ]]; then
            pretty_print "$indicator_error Cannot check for updates."
        fi
        return $major_error
    fi
    echo "$latest_version"
    return 0
}

print_update_info() {
    local top_border="┌────────────────────────────────────────────┐"
    local side_border="│"
    local bottom_border="└────────────────────────────────────────────┘"

    if [[ -z "$latest_version" ]]; then
        latest_version=$(get_latest_version_number "quiet")
    fi

    # If current version number is not the latest, print update info
    if [[ "${current_version#v}" != "${latest_version#v}" ]]; then
        # If reminder already printed before, don't print again
        if [[ "$1" == "remind" ]] && $printed_update_info; then
            return
        fi
        pretty_print "$top_border"
        pretty_print "$side_border ${bold}${underlined}${bright_yellow}A new version of 42free is available.${reset}      $side_border"
        pretty_print "$side_border Current version: $(printf "%-*s" 36 "${bold}${current_version#v}${reset}")$side_border"
        pretty_print "$side_border Latest version:  $(printf "%-*s" 36 "${bold}${latest_version#v}${reset}")$side_border"
        pretty_print "$side_border To see the changelog, visit                $side_border"
        pretty_print "$side_border ${underlined}${bright_blue}https://github.com/itislu/42free/releases${reset}. $side_border"
        if [[ "$1" == "remind" ]]; then
            pretty_print "$side_border Run '42free --update' to update.${reset}           $side_border"
        fi
        pretty_print "$bottom_border"
        printed_update_info=true
    fi
}

# Prompt for update if a new version is available and run the new version with the original arguments
# Possible arguments to this function:
#   - "quiet": Do not print any messages
#   - "exit": Exit after updating
update() {
    if ! latest_version=$(get_latest_version_number "$1"); then
        return $?
    fi

    # Prompt for update if current version number is not the latest
    if [[ "${current_version#v}" != "${latest_version#v}" ]]; then
        print_update_info
        if prompt_single_key "$prompt_update"; then
            bash <("$downloader" "$downloader_opts_stdout" "$install_script") "update"; update_status=$?; if [[ $update_status -eq 0 && "$1" != "exit" ]]; then exec "$0" "${args[@]}"; fi; ft_exit $update_status
        else
            pretty_print "Not updating."
        fi
    elif [[ "$1" != "quiet" ]]; then
        pretty_print "You are already using the latest version of 42free."
    fi

    if [[ "$1" == "exit" ]]; then
        ft_exit $success
    fi
    return $success
}

# Filter out default arguments that do not exist or are already symbolic links
filter_default_args() {
    local filtered_default_args=()

    for default_arg in "${default_args[@]}"; do
        if [[ -e "$default_arg" ]] && [[ ! -L "$default_arg" ]] && [[ $(realpath "$default_arg") != $target_base/* ]]; then
            filtered_default_args+=("$default_arg")
        fi
    done
    default_args=("${filtered_default_args[@]}")
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

change_sgoinfre() {
    local prompt
    local changed_sgoinfre

    if [[ -n "$SGOINFRE" ]]; then
        pretty_print "Your personal sgoinfre directory for 42free is currently set to '${bold}$SGOINFRE${reset}'."
        prompt="If you would like to change it, please enter a new path:"
    else
        pretty_print "Your personal sgoinfre directory for 42free is currently not set."
        prompt="Please enter the path to your personal sgoinfre directory:"
    fi
    prompt_sgoinfre_path "$prompt"
    # Change SGOINFRE in all shell config files
    pretty_print "Saving the path of your sgoinfre directory..."
    changed_sgoinfre=false
    for config_file in "$bash_config" "$zsh_config" "$fish_config"; do
        if change_config "export SGOINFRE='$sgoinfre'" "$config_file" 2>/dev/null; then
            changed_sgoinfre=true
        fi
    done
    if $changed_sgoinfre; then
        pretty_print "$indicator_success Your personal sgoinfre directory for 42free is now set to '${bold}$sgoinfre${reset}'."
    else
        pretty_print "Your personal sgoinfre directory for 42free was already set to '${bold}$sgoinfre${reset}'."
    fi
}

change_max_sizes() {
    local changed_max_size

    for dir in home sgoinfre; do
        changed_max_size=false

        # Construct variable name
        max_size_var_name="$(capitalize_full "$dir")_MAX_SIZE"

        # Prompt user for the maximum allowed size of the directory
        while true; do
            pretty_print "Enter the maximum allowed size of your ${bold}$dir${reset} directory in GB:"
            read -rp "> "
            if [[ $REPLY =~ ^[0-9]+$ ]]; then
                declare "$max_size_var_name=$REPLY"
                break
            fi
            pretty_print "${bold}${red}Invalid input. Please enter a number.${reset}"
        done

        # Change MAX_SIZE in all shell config files
        for config_file in "$bash_config" "$zsh_config" "$fish_config"; do
            if change_config "export $max_size_var_name=${!max_size_var_name}" "$config_file" 2>/dev/null; then
                changed_max_size=true
            fi
        done

        if $changed_max_size; then
            pretty_print "$indicator_success The warning size for your $dir directory has been set to ${bold}${!max_size_var_name}GB${reset}."
        else
            pretty_print "The warning size for your $dir directory was already set to ${bold}${!max_size_var_name}GB${reset}."
        fi
    done
}

# Remove everything added from installation in all shell config files
clean_config_files() {
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
            if grep -q "alias 42free=" "$config_file" 2>/dev/null; then
                sed_inplace "/^alias 42free=/d" "$config_file" 2>/dev/null
                changed_config=true
                pretty_print "${yellow}42free alias removed from $shell_name.${reset}"
            fi
            if grep -q "^export HOME_MAX_SIZE=" "$config_file" 2>/dev/null; then
                sed_inplace "/^export HOME_MAX_SIZE=/d" "$config_file" 2>/dev/null
                changed_config=true
                pretty_print "${yellow}HOME_MAX_SIZE environment variable removed from $shell_name.${reset}"
            fi
            if grep -q "^export SGOINFRE_MAX_SIZE=" "$config_file" 2>/dev/null; then
                sed_inplace "/^export SGOINFRE_MAX_SIZE=/d" "$config_file" 2>/dev/null
                changed_config=true
                pretty_print "${yellow}SGOINFRE_MAX_SIZE environment variable removed from $shell_name.${reset}"
            fi
            if grep -q "^export SGOINFRE=" "$config_file" 2>/dev/null; then
                sed_inplace "/^export SGOINFRE=/d" "$config_file" 2>/dev/null
                changed_config=true
                pretty_print "${yellow}SGOINFRE environment variable removed from $shell_name.${reset}"
            fi
        fi
    done
}

uninstall() {
    if prompt_with_enter "$prompt_uninstall"; then
        pretty_print "Uninstalling 42free..."
        if stderr=$(rm -f "$script_path" 2>&1); then
            pretty_print "${yellow}Script deleted.${reset}"
            # If script_dir is empty, remove it
            find "$script_dir" -maxdepth 0 -type d -empty -delete 2>/dev/null
            clean_config_files
            # Remove everything set by 42free from current shell environment
            if alias 42free &>/dev/null || [[ -n "$HOME_MAX_SIZE" ]] || [[ -n "$SGOINFRE_MAX_SIZE" ]] || [[ -n "$SGOINFRE" ]]; then
                unalias 42free 2>/dev/null
                unset HOME_MAX_SIZE SGOINFRE_MAX_SIZE SGOINFRE
                changed_config=true
            fi
            pretty_print "$indicator_success 42free has been uninstalled."
            ft_exit $success
        else
            pretty_print "$indicator_error Cannot uninstall 42free."
            print_stderr
            ft_exit $major_error
        fi
    else
        pretty_print "Not uninstalling."
        ft_exit $success
    fi
}

# Process options
args=()
args_amount=0
restore=false
while (( $# )); do
    case "$1" in
        -r|--restore)
            restore=true
            ;;
        -s|--sgoinfre)
            change_sgoinfre
            ft_exit $success
            ;;
        -m|--max-size)
            change_max_sizes
            ft_exit
            ;;
        -u|--update)
            update "exit"
            ;;
        -h)
            pretty_print "$msg_manual_short"
            ft_exit $success
            ;;
        --help)
            print_update_info "remind"
            pretty_print "$msg_manual"
            ft_exit $success
            ;;
        -v|--version)
            print_update_info "remind"
            pretty_print "$msg_version"
            ft_exit $success
            ;;
        --uninstall)
            uninstall
            ;;
        --)
            # End of options
            shift
            while (( $# )); do
                args+=("$1")
                args_amount=$(( args_amount + 1 ))
                shift
            done
            break
            ;;
        -*)
            # Unknown option
            pretty_print "Unknown option: '$1'"
            ft_exit $input_error
            ;;
        *)
            # Non-option argument
            args+=("$1")
            args_amount=$(( args_amount + 1 ))
            ;;
    esac
    shift
done

# Check for updates
update "quiet"

# Check if the script received any targets
if [[ -z "${args[*]}" ]]; then
    no_user_args=true
else
    no_user_args=false
fi

# Print header
pretty_print "$header"
pretty_print "$delim_big"
echo

# Check if path to user's sgoinfre directory is known
if [[ ! -d "$sgoinfre" ]]; then
    find_sgoinfre
fi

# Save possible mount points of sgoinfre
sgoinfre_std="$sgoinfre"
sgoinfre_alt="$sgoinfre_alt_mount/$sgoinfre"

# Check if the permissions of user's sgoinfre directory are rwx------
sgoinfre_permissions=$(stat_human_readable "$sgoinfre" 2>/dev/null)
# Remove 'd' from permissions for more clarity
sgoinfre_permissions=${sgoinfre_permissions#d}
if ! $restore && [[ "$sgoinfre_permissions" != "rwx------" ]]; then
    if ! change_sgoinfre_permissions; then
        ft_exit $major_error
    fi
fi

# Check if user has a symbolic link to their sgoinfre directory in their home directory
sgoinfre_symlink=$(find "$HOME" -maxdepth 1 -type l -lname "$sgoinfre" -print -quit 2>/dev/null)
if [[ -z $sgoinfre_symlink ]]; then
    if ! create_sgoinfre_symlink; then
        ft_exit $major_error
    fi
fi

# Check which direction the script should move the directories or files
if ! $restore; then
    source_base="$HOME"
    source_name="home"
    target_base="$sgoinfre"
    target_name="sgoinfre"
    target_max_size=$sgoinfre_max_size
    operation="moving"
    operation_success="moved"
    outcome="freed"
else
    source_base="$sgoinfre"
    source_name="sgoinfre"
    target_base="$HOME"
    target_name="home"
    target_max_size=$home_max_size
    operation="restoring"
    operation_success="restored"
    outcome="occupied"
    convert_default_args "$sgoinfre"
fi

# If no arguments were given, use default arguments
if $no_user_args; then
    filter_default_args
    args=("${default_args[@]}")
fi

# Store the amount of arguments
args_amount=${#args[@]}
args_index=0
need_delim=false

# Check if nothing to be done
if [[ $args_amount -eq 0 ]]; then
    if $restore; then
        example="42free -r /path/to/directory/in/sgoinfre symLinkInCurDir"
    else
        example="42free /path/to/large/directory largeFileInCurDir"
    fi
    pretty_print "${bold}Nothing to be done.${reset}"
    pretty_print "You can specify which directories or files you would like to move to $target_name with arguments."
    pretty_print "Example: '${bold}$example${reset}'"
    pretty_print "Run '42free --help' for more information."
fi

# Loop over all arguments
for arg in "${args[@]}"; do
    args_index=$(( args_index + 1 ))

    # Print reminder to close all programs first in first iteration of default arguments
    if [[ $args_index -eq 1 ]] && $no_user_args; then
        pretty_print "$msg_close_programs"
        pretty_print "$msg_manual_reminder"
        echo
        # Print all default arguments and prompt user if they agree to all of them
        pretty_print "${bold}The following directories will be moved to $target_name:${reset}"
        for default_arg in "${default_args[@]}"; do
            printf "%s\n" "  ▸ $default_arg"
        done
        echo
        if prompt_single_key "$prompt_agree_all"; then
            no_user_args=false
        fi
        echo
    fi

    # Print delimiter
    if $need_delim; then
        echo
        pretty_print "$delim_small"
        echo
    fi
    need_delim=true

    # Check if argument is an absolute or relative path
    if [[ "$arg" == /* ]]; then
        arg_path="$arg"
        invalid_path_msg="$indicator_error Absolute paths have to lead to a path in your ${bold}home${reset} or ${bold}sgoinfre${reset} directory."
    else
        arg_path="$current_dir/$arg"
        invalid_path_msg="$indicator_error The current directory is not in your ${bold}home${reset} or ${bold}sgoinfre${reset} directory."
    fi

    # Make sure all defined mount points of sgoinfre work with the script
    if [[ "$arg_path" == $sgoinfre_alt/* ]]; then
        sgoinfre="$sgoinfre_alt"
    else
        sgoinfre="$sgoinfre_std"
    fi
    # Update variables with updated sgoinfre path
    if ! $restore; then
        target_base="$sgoinfre"
    else
        source_base="$sgoinfre"
    fi

    # Construct the source and target paths
    if [[ "$arg_path" == $source_base/* ]]; then
        source_path="$arg_path"
        source_subpath="${source_path#"$source_base/"}"
        target_path="$target_base/$source_subpath"
        target_subpath="${target_path#"$target_base/"}"
    elif [[ "$arg_path" == $target_base/* ]]; then
        target_path="$arg_path"
        target_subpath="${target_path#"$target_base/"}"
        source_path="$source_base/$target_subpath"
        source_subpath="${source_path#"$source_base/"}"
    else
        # If the result is neither a path in the source nor target base directory, skip the argument
        pretty_print "$invalid_path_msg"
        print_skip_arg "$arg"
        bad_input=true
        continue
    fi

    # Print progress out of total amount of arguments
    pretty_print "${bold}${underlined}${bright_yellow}[$args_index/$args_amount]${reset}"
    pretty_print "'$arg' ➜ $target_name"
    echo

    # Construct useful variables from the paths
    source_dirpath=$(dirname "$source_path")
    source_basename=$(basename "$source_path")
    target_dirpath=$(dirname "$target_path")

    # Check if the source directory or file exists
    if [[ ! -e "$source_path" ]]; then
        # Check if the source directory or file has already been moved to sgoinfre and is missing a symbolic link
        if ! $restore && [[ -e "$target_path" ]]; then
            pretty_print "'${bright_yellow}$source_path${reset}' has already been moved to sgoinfre."
            pretty_print "It is located at '${bright_green}$target_path${reset}'."
            if prompt_single_key "$prompt_symlink"; then
                if stderr=$(symlink "$target_path" "$source_path" 2>&1); then
                    pretty_print "$indicator_success Symbolic link created."
                else
                    pretty_print "$indicator_error Cannot create symbolic link."
                    print_stderr
                    syscmd_failed=true
                fi
            else
                print_skip_arg "$arg"
                arg_skipped=true
            fi
        elif ! $no_user_args; then
            pretty_print "$indicator_error '${bright_red}$source_path${reset}' does not exist."
            bad_input=true
        else
            need_delim=false
        fi
        continue
    fi

    # Check if the parent directory of the argument is already in the target base directory
    real_arg_path=$(realpath "$arg_path")
    real_arg_dirpath=$(realpath "$(dirname "$arg_path")")
    if { [[ "$arg_path" == $source_base/* ]] && [[ "$real_arg_dirpath/" != $source_base/* ]]; } ||
       { [[ "$arg_path" == $target_base/* ]] && [[ "$real_arg_dirpath/" != $target_base/* ]]; }; then
        pretty_print "$indicator_error '${bright_blue}$source_subpath${reset}' is already in the $target_name directory."
        pretty_print "Real path: '${bold}$real_arg_path${reset}'."
        print_skip_arg "$arg"
        bad_input=true
        continue
    fi

    # If the source directory or file has already been moved to sgoinfre, skip it
    if [[ -L "$source_path" ]]; then
        real_source_path=$(realpath "$source_path")
        if ! $restore && [[ "$real_source_path" =~ ^($sgoinfre_std|$sgoinfre_alt)/ ]]; then
            if ! $no_user_args; then
                pretty_print "'${bold}${bright_cyan}$source_subpath${reset}' has already been moved to sgoinfre."
                pretty_print "It is located at '$real_source_path'."
                print_skip_arg "$arg"
            else
                need_delim=false
            fi
            continue
        fi
    fi

    # If no user arguments, ask user if they want to process the current argument
    if $no_user_args && [[ -e "$source_path" ]]; then
        pretty_print "This will move '${bold}$source_path${reset}' to the $target_name directory."
        if ! prompt_single_key "$prompt_continue"; then
            print_skip_arg "$arg"
            continue
        fi
    fi

    # Check if the source file is a symbolic link
    if [[ -L "$source_path" ]]; then
        pretty_print "$indicator_warning '${bold}${bright_cyan}$source_path${reset}' is a symbolic link."
        if ! prompt_single_key "$prompt_continue_still"; then
            print_skip_arg "$arg"
            arg_skipped=true
            continue
        fi
    fi

    # Check if an existing directory or file would get replaced
    if [[ -e "$target_path" ]] && ! ($restore && [[ -L "$target_path" ]]); then
        pretty_print "$indicator_warning '${bold}$source_subpath${reset}' already exists in the $target_name directory."
        if [[ -d "$target_path" ]]; then
            prompt="$prompt_merge"
        else
            prompt="$prompt_replace"
        fi
        if ! prompt_with_enter "$prompt"; then
            print_skip_arg "$arg"
            arg_skipped=true
            continue
        fi
    fi

    # Get the current sizes of the source and target base directories
    if [[ -z "$target_base_size_in_kb" ]]; then
        pretty_print "Getting the current sizes of the $source_name and $target_name directories..."

        tmpfile_source_base_size="/tmp/42free~$$~source_base_size"
        tmpfile_target_base_size="/tmp/42free~$$~target_base_size"

        # Run parallel jobs and wait for both to finish
        du -sk "$source_base" 2>/dev/null | cut -f1 > $tmpfile_source_base_size &
        jobs+=($!)
        du -sk "$target_base" 2>/dev/null | cut -f1 > $tmpfile_target_base_size &
        jobs+=($!)
        wait_for_jobs "all" "searching" "${jobs[@]}"

        # Read the sizes from the temporary files
        source_base_size_in_kb=$(cat $tmpfile_source_base_size 2>/dev/null)
        target_base_size_in_kb=$(cat $tmpfile_target_base_size 2>/dev/null)
        rm -f $tmpfile_source_base_size $tmpfile_target_base_size
    fi

    # Get the size of the directory or file to be moved
    pretty_print "Getting the size of '$source_basename'..."
    source_size="$(du -sh "$source_path" 2>/dev/null | cut -f1)B"
    source_size_in_kb=$(du -sk "$source_path" 2>/dev/null | cut -f1)

    # Get the size of any target that will be replaced
    existing_target_size_in_kb="$(du -sk "$target_path" 2>/dev/null | cut -f1)"

    # Convert target_max_size from GB to kilobytes
    max_size_in_kb=$(( target_max_size * 1024 * 1024 ))

    # Check if the target directory would go above its maximum recommended size
    if (( target_base_size_in_kb + source_size_in_kb - existing_target_size_in_kb > max_size_in_kb )); then
        pretty_print "$indicator_warning $(capitalize_initial "$operation") '${bold}$source_subpath${reset}' would cause the ${bold}$target_name${reset} directory to go above ${bold}${target_max_size}GB${reset}."
        if ! prompt_single_key "$prompt_continue_still"; then
            print_skip_arg "$arg"
            arg_skipped=true
            continue
        fi
    fi

    # When moving files back to home, first remove the symbolic link
    if $restore; then
        if [[ -L "$target_path" ]]; then
            rm -f "$target_path" 2>/dev/null
        fi
        if [[ -L "$target_path~42free_tmp~" ]]; then
            rm -f "$target_path~42free_tmp~" 2>/dev/null
        fi
    fi

    # Create the same directory structure as in source
    if ! stderr=$(mkdir -p "$target_dirpath" 2>&1); then
        pretty_print "$indicator_error Cannot create the directory structure for '$target_path'."
        print_stderr
        syscmd_failed=true
        # If not last argument, ask user if they want to continue with the other arguments
        if [[ $args_index -lt $args_amount ]] && ! prompt_with_enter "$prompt_continue_with_rest"; then
            pretty_print "Skipping the rest of the arguments."
            break
        fi
        continue
    fi

    # Move the files
    if ! move_files "$source_path" "$target_dirpath" "$operation"; then
        pretty_print "$indicator_error Could not fully move '${bold}$source_basename${reset}' to '${bold}$target_dirpath${reset}'."
        print_one_stderr
        if [[ -d "$source_path" ]]; then
            # Rename the directory with the files that could not be moved
            source_old="$source_path~42free-old_$(get_timestamp)~"
            if mv -T "$source_path" "$source_old" 2>/dev/null; then
                link_path="$source_path"
                link_create_msg="Symbolic link created and the files that could not be moved are left in '${bold}$source_old${reset}'."
            else
                source_old="$source_path"
                link_path="$source_path~42free_tmp~"
                link_create_msg="Symbolic link left behind with a tmp name."
            fi
            # Create the symbolic link
            symlink "$target_path" "$link_path" 2>/dev/null
            pretty_print "$link_create_msg"

            # Calculate and print how much space was already partially moved
            leftover_size_in_kb=$(du -sk "$source_old" 2>/dev/null | cut -f1)
            outcome_size_in_kb=$(( source_size_in_kb - leftover_size_in_kb ))
            outcome_size="$(bytes_to_human $(( outcome_size_in_kb * 1024 )))"
            pretty_print "${bold}$outcome_size${reset} of ${bold}$source_size${reset} $outcome."

            # Ask user if they wish to restore what was already moved or leave the partial copy
            if prompt_single_key "Do you wish to restore what was partially moved to the $target_name directory back to the $source_name directory?"; then
                rm -f "$link_path" 2>/dev/null;
                mv -T "$source_old" "$source_path" 2>/dev/null
                if ! move_files "$target_path" "$source_dirpath" "restoring"; then
                    pretty_print "$indicator_error Could not fully restore '$source_basename' to '$source_dirpath'."
                    print_one_stderr
                    pretty_print "The rest of the partial copy is left in '${bold}$target_path${reset}'."
                else
                    pretty_print "'${bold}$source_basename${reset}' has been restored to '${bold}$source_dirpath${reset}'."
                fi
                pretty_print "Try to close all programs before trying again."
            else
                pretty_print "Try to close all programs and move the rest from '${bold}$source_old${reset}' manually."
            fi
        else
            pretty_print "Try to close all programs and try again."
        fi

        # If not last argument, ask user if they want to continue with the other arguments
        if [[ $args_index -lt $args_amount ]] && ! prompt_with_enter "$prompt_continue_with_rest"; then
            pretty_print "Skipping the rest of the arguments."
            break
        fi

        # Force recalculation of the target directory size in next iteration
        unset target_base_size_in_kb
        continue
    fi
    pretty_print "$indicator_success '${bright_yellow}$source_basename${reset}' successfully $operation_success to '${bright_green}$target_dirpath${reset}'."

    if ! $restore; then
        # Create the symbolic link
        if stderr=$(symlink "$target_path" "$source_path" 2>&1); then
            pretty_print "Symbolic link left behind."
        else
            pretty_print "$indicator_warning Cannot create symbolic link with name '$source_basename'."
            print_stderr
            syscmd_failed=true
            # Create the symbolic link with a tmp name
            if stderr=$(symlink "$target_path" "$source_path~42free_tmp~" 2>&1); then
                pretty_print "Symbolic link left behind with a tmp name."
            else
                print_stderr
            fi
            # If not last argument, ask user if they want to continue with the other arguments
            if [[ $args_index -lt $args_amount ]] && ! prompt_with_enter "$prompt_continue_with_rest"; then
                pretty_print "Skipping the rest of the arguments."
                break
            fi
        fi
    fi

    # Update the directory sizes
    source_base_size_in_kb=$(( source_base_size_in_kb - source_size_in_kb ))
    target_base_size_in_kb=$(( target_base_size_in_kb + source_size_in_kb - existing_target_size_in_kb ))

    # Print result
    if ! $restore; then
        outcome_color="${bright_cyan}"
    else
        outcome_color="${bright_blue}"
    fi
    pretty_print "${bold}${outcome_color}$source_size $outcome.${reset}"
    print_available_space "$source_base_size_in_kb" "$target_base_size_in_kb"

# Process the next argument
done

ft_exit
