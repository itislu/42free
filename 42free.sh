#!/bin/bash

current_version="v1.3.1+dev"

default_args=(\
"$HOME/.cache" \
"$HOME/.config/Code/Cache" \
"$HOME/.config/Code/CachedData" \
"$HOME/.config/Code/User/workspaceStorage" \
"$HOME/.var/app/com.discordapp.Discord" \
"$HOME/.var/app/com.slack.Slack" \
"$HOME/.var/app/com.brave.Browser/cache" \
"$HOME/.var/app/com.google.Chrome/cache" \
"$HOME/.var/app/com.opera.Opera/cache" \
"$HOME/.var/app/org.mozilla.firefox/cache" \
)

# Standard variables
stderr=""
current_dir=$(pwd)
script_dir="$HOME/.scripts"
script_path="$script_dir/42free.sh"
sgoinfre_root="/sgoinfre/goinfre/Perso/$USER"
sgoinfre_alt="/nfs/sgoinfre/goinfre/Perso/$USER"
sgoinfre="$sgoinfre_root"
sgoinfre_permissions=$(stat -c "%A" "$sgoinfre")

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

# Exit codes
success=0
input_error=1
minor_error=2
major_error=3

# Flags
bad_input=false
arg_skipped=false
syscmd_failed=false
changed_config=false
printed_update_info=false

# Colors and styles
sty_res="\e[0m"
sty_bol="\e[1m"
sty_und="\e[4m"
sty_red="\e[31m"
sty_yel="\e[33m"
sty_bri_red="\e[91m"
sty_bri_gre="\e[92m"
sty_bri_yel="\e[93m"
sty_bri_blu="\e[94m"
sty_bri_cya="\e[96m"

header="
               ${sty_bol}${sty_bri_yel}📁  42free  📁${sty_res}"
tagline="\
           ${sty_bol}${sty_bri_yel}Never run \`ncdu\` again${sty_res}"
delim_small="\
      --------------------------------"
delim_big="\
    ${sty_und}                                    ${sty_res}"

# Indicators
indicator_error="${sty_bol}${sty_red}ERROR:${sty_res}"
indicator_warning="${sty_bol}${sty_bri_yel}WARNING:${sty_res}"
indicator_success="${sty_bol}${sty_bri_gre}SUCCESS:${sty_res}"

# Messages
msg_manual="\
$header
$tagline
$delim_big

The files get moved from '$HOME' to '$sgoinfre'.

A symbolic link is left behind in the original location.
You only need to run 42free once for every directory or file you want to free the space of.
All programs will then access them through the symlink and they will accumulate their space outside of your home directory.

$delim_small

${sty_bol}${sty_und}Usage:${sty_res} ${sty_bol}42free${sty_res} [target1 target2 ...]
    If no arguments are given, 42free will make some suggestions.
    Target paths can be absolute or relative to your current directory.
    42free will automatically detect if an argument is the source or the destination.
    Closing all programs first will help to avoid errors during the move.

${sty_bol}${sty_und}Options:${sty_res} You can pass options anywhere in the arguments.
    -r, --reverse    Reverse the operation and move the directories or files
                     back to their original location in home.
    -m, --max-size   Change the warning sizes for the home and sgoinfre directories (in GB).
                     Current sizes: HOME_MAX_SIZE=$home_max_size, SGOINFRE_MAX_SIZE=$sgoinfre_max_size
    -u, --update     Check for a new version of 42free.
    -h, --help       Display this help message and exit.
    -v, --version    Display version information and exit.
        --uninstall  Uninstall 42free.
    --               Stop interpreting options.

${sty_bol}${sty_und}Error codes:${sty_res}
    1 - Input error
        An argument was invalid.
          (no arguments, unknown option, invalid path, file does not exist)
    2 - Minor error
        An argument was skipped.
          (symbolic link, file conflict, no space left)
    3 - Major error
        An operation failed.
          (sgoinfre permissions, update failed, move failed, restore failed, cleanup failed)

$delim_small

To contribute, report bugs or share improvement ideas, visit ${sty_und}${sty_bri_blu}https://github.com/itislu/42free${sty_res}.
\n"

msg_version="\
${sty_bol}42free $current_version${sty_res}
A script made for 42 students to take advantage of symbolic links to free up storage without data loss.
For more information, visit ${sty_und}${sty_bri_blu}https://github.com/itislu/42free${sty_res}."

msg_sgoinfre_permissions="\
$indicator_warning The permissions of your personal sgoinfre directory are not set to '${sty_bol}rwx------${sty_res}'.
They are currently set to '${sty_bol}$sgoinfre_permissions${sty_res}'.
It is ${sty_bol}highly${sty_res} recommended to change the permissions so that other students cannot access the files you will move to sgoinfre."

msg_sgoinfre_permissions_keep="Keeping the permissions of '$sgoinfre' as '$sgoinfre_permissions'."

msg_close_programs="${sty_bol}${sty_bri_yel}Close all programs first to avoid errors during the move.${sty_res}"

# Prompts
prompt_update="Do you wish to update? [${sty_bol}Y${sty_res}/${sty_bol}n${sty_res}]"
prompt_continue="Do you wish to continue? [${sty_bol}Y${sty_res}/${sty_bol}n${sty_res}]"
prompt_continue_still="Do you still wish to continue? [${sty_bol}y${sty_res}/${sty_bol}N${sty_res}]"
prompt_continue_with_rest="Do you wish to continue with the other arguments? [${sty_bol}y${sty_res}/${sty_bol}N${sty_res}]"
prompt_change_permissions="Do you wish to change the permissions of '$sgoinfre' to '${sty_bol}rwx------${sty_res}'? [${sty_bol}Y${sty_res}/${sty_bol}n${sty_res}]"
prompt_symlink="Do you wish to create a symbolic link to it? [${sty_bol}Y${sty_res}/${sty_bol}n${sty_res}]"
prompt_replace="Do you wish to continue and replace any duplicate files? [${sty_bol}y${sty_res}/${sty_bol}N${sty_res}]"

# Automatically detect the size of the terminal window and preserve word boundaries at the edges
pretty_print()
{
    printf "%b" "$1" | fmt -sw $(tput cols)
}

print_stderr()
{
    while IFS= read -r line; do
        pretty_print "STDERR: $line"
    done <<< "$stderr"
}

print_one_stderr()
{
    line=$(head -n 1 <<< "$stderr")
    pretty_print "STDERR: $line"
    if [[ $(wc -l <<< "$stderr") -gt 1 ]]; then
        pretty_print "STDERR: ..."
    fi
}

ft_exit()
{
    if $changed_config; then
        # Start the default shell to make changes of the shell config available immediately
        if [ "$1" -eq 0 ] && [ -x "$SHELL" ]; then
            exec $SHELL
        fi
        # If exec failed, inform the user to start a new shell
        pretty_print "Please start a new shell to make the changed 42free configs available."
    fi
    exit "$1"
}

print_skip_arg()
{
    pretty_print "Skipping '$1'."
}

# Prompt the user for confirmation
# Default is 'no', for 'yes' needs y/Y/yes/Yes + Enter key
prompt_with_enter()
{
    pretty_print "$1"
    read -rp "> "
    if [[ $REPLY =~ ^[Yy](es)?$ ]]; then
        return 0
    fi
    return 1
}

# Prompt the user for confirmation
# Default is 'yes', only needs y/Y key
prompt_single_key()
{
    pretty_print "$1"
    read -n 1 -rp "> "
    if [[ -n $REPLY ]]; then
        echo
    fi
    if [[ $REPLY =~ ^([Yy]?)$|^$ ]]; then
        return 0
    fi
    return 1
}

prompt_restore()
{
    pretty_print "Do you wish to leave it like that? [${sty_bol}y${sty_res}/${sty_bol}N${sty_res}]"
    pretty_print "- Selecting ${sty_bol}no${sty_res} will restore what was already moved to the $target_name directory back to the $source_name directory."
    prompt_with_enter
    return $(( ! $? ))
}

move_files()
{
    local source_path=$1
    local target_dirpath=$2
    local operation=$3

    # Move the files in a background job
    pretty_print "${operation^} '$(basename "$source_path")' to '$target_dirpath'..."
    stderr=$(rsync -a --remove-source-files "$source_path" "$target_dirpath/" 2>&1) &
    rsync_job=$!

    # Wait for rsync to finish
    wait_for_jobs "$operation" $rsync_job
    rsync_status=$?

    cleanup_empty_dirs "$source_path"

    # Check the exit status of rsync
    if [[ $rsync_status -ne 0 ]]; then
        syscmd_failed=true
    fi
    return $rsync_status
}

cleanup_empty_dirs()
{
    local dir=$1

    find "$dir" -type d -empty -delete 2>/dev/null
    while [ "$dir" != "$HOME" ] && [ "$dir" != "$sgoinfre" ]; do
        rmdir "$dir" 2>/dev/null
        dir=$(dirname "$dir")
    done
}

clear_prev_line()
{
    printf "\e[1K\e[1A\n"
}

show_cursor()
{
    tput cnorm
    clear_prev_line
    exit 130
}

any_job_running()
{
    local job_pids=("$@")

    for job_pid in "${job_pids[@]}"; do
        if kill -0 "$job_pid" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

wait_for_jobs()
{
    if [[ "$1" == "moving" ]]; then
        local pacing=0.1
        local frames=(
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
        shift
    elif [[ "$1" == "restoring" ]]; then
        local pacing=0.1
        local frames=(
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
        shift
    elif [[ "$1" == "searching" ]]; then
        local pacing=0.5
        local frames=(
            '  🔎📁📁📁📁📁📁'
            '  📄🔎📁📁📁📁📁'
            '  📄📄🔎📁📁📁📁'
            '  📄📄📄🔎📁📁📁'
            '  📄📄📄📄🔎📁📁'
            '  📄📄📄📄📄🔎📁'
            '  📄📄📄📄📄📄🔎'
            '  📄📄📄📄📄📄🔍'
            '  📄📄📄📄📄🔍📁'
            '  📄📄📄📄🔍📁📁'
            '  📄📄📄🔍📁📁📁'
            '  📄📄🔍📁📁📁📁'
            '  📄🔍📁📁📁📁📁'
            '  🔍📁📁📁📁📁📁'
            )
        shift
    else
        local pacing=0.25
        local frames=(
            '  | '
            '  / '
            '  - '
            '  \ '
            )
    fi

    local job_pids=("$@")
    local exit_status=0

    # Trap SIGINT to enable cursor again and clear line
    trap show_cursor SIGINT

    # Hide cursor
    tput civis
    # Print frames while jobs are running
    while any_job_running "${job_pids[@]}"; do
        for frame in "${frames[@]}"; do
            if ! any_job_running "${job_pids[@]}"; then
                break
            fi
            printf "\r%s" "$frame"
            sleep "$pacing"
        done
    done
      # Clear line on completion
    printf "\r\e[K"
    # Show cursor
    tput cnorm

    # Reset signal trap
    trap - SIGINT

    # Collect exit status
    for job_pid in "${job_pids[@]}"; do
        wait "$job_pid" 2>/dev/null
        job_exit_status=$?
        if [[ $job_exit_status -ne 0 ]]; then
            exit_status=$job_exit_status
        fi
    done
    return $exit_status
}

# Calculate a color based on the percentage of used space
calculate_usage_color()
{
    local size=$1
    local max_size=$2
    local percentage
    local color

    # Calculate the percentage of used space
    percentage=$(awk -v s="$size" -v ms="$max_size" 'BEGIN { printf "%.2f", s / ms * 100 }')

    if (( $(echo "$percentage >= 100" | bc -l) )); then
        color="${sty_red}"
    elif (( $(echo "$percentage >= 90" | bc -l) )); then
        color="${sty_bri_red}"
    elif (( $(echo "$percentage >= 80" | bc -l) )); then
        color="${sty_bri_yel}"
    else
        color="${sty_bri_gre}"
    fi
    echo "$color"
}

print_available_space()
{
    local source_base_size_in_bytes=$1
    local target_base_size_in_bytes=$2
    local source_base_size
    local target_base_size
    local home_size
    local sgoinfre_size
    local home_color
    local sgoinfre_color

    source_base_size=$(echo "$source_base_size_in_bytes/1024/1024/1024" | bc -l | xargs printf "%.2f")
    target_base_size=$(echo "$target_base_size_in_bytes/1024/1024/1024" | bc -l | xargs printf "%.2f")

    if ! $reverse; then
        home_size=$source_base_size
        sgoinfre_size=$target_base_size
    else
        home_size=$target_base_size
        sgoinfre_size=$source_base_size
    fi

    pretty_print "${sty_bol}${sty_und}Space used:${sty_res}"
    if [ "$home_max_size" -gt 0 ]; then
        home_color=$(calculate_usage_color "$home_size" "$home_max_size")
        printf "${sty_bol}  %-10s ${home_color}%5.2f${sty_res}${sty_bol}/%dGB${sty_res}\n" "Home:" "$home_size" "$home_max_size"
    else
        printf "${sty_bol}  %-10s %5.2fGB${sty_res}\n" "Home:" "$home_size"
    fi
    if [ "$sgoinfre_max_size" -gt 0 ]; then
        sgoinfre_color=$(calculate_usage_color "$sgoinfre_size" "$sgoinfre_max_size")
        printf "${sty_bol}  %-10s ${sgoinfre_color}%5.2f${sty_res}${sty_bol}/%dGB\n${sty_res}" "Sgoinfre:" "$sgoinfre_size" "$sgoinfre_max_size"
    else
        printf "${sty_bol}  %-10s %5.2fGB${sty_res}\n" "Sgoinfre:" "$sgoinfre_size"
    fi
}

get_timestamp()
{
    date +%Y%m%d%H%M%S
}

get_latest_version_number()
{
    # Check if curl or wget is available
    if [ -z "$downloader" ]; then
        if [[ "$1" != "silent" ]]; then
            pretty_print "$indicator_error Cannot check for updates."
            pretty_print "Neither ${sty_bol}${sty_red}curl${sty_res} nor ${sty_bol}${sty_red}wget${sty_res} was found."
            pretty_print "Please install one of them and try again."
        fi
        return $major_error
    fi

    # Fetch the latest version from the git tags on GitHub
    latest_version=$("$downloader" "$downloader_opts_stdout" "https://api.github.com/repos/itislu/42free/tags")
    latest_version=$(echo "$latest_version" | grep -m 1 '"name":' | cut -d '"' -f 4) 2>/dev/null
    if [ -z "$latest_version" ]; then
        if [[ "$1" != "silent" ]]; then
            pretty_print "$indicator_error Cannot check for updates."
        fi
        return $major_error
    fi
    echo "$latest_version"
    return 0
}

print_update_info()
{
    local top_border="┌────────────────────────────────────────────┐"
    local side_border="│"
    local bottom_border="└────────────────────────────────────────────┘"

    if [ -z "$latest_version" ]; then
        latest_version=$(get_latest_version_number "silent")
    fi

    if [[ "${current_version#v}" != "${latest_version#v}" ]]; then
        # If reminder already printed before, don't print again
        if [[ "$1" == "remind" ]] && $printed_update_info; then
            return
        fi
        pretty_print "$top_border"
        pretty_print "$side_border ${sty_bol}${sty_und}${sty_bri_yel}A new version of 42free is available.${sty_res}      $side_border"
        pretty_print "$side_border Current version: ${sty_bol}${current_version#v}${sty_res}                 $side_border"
        pretty_print "$side_border Latest version: ${sty_bol}${latest_version#v}${sty_res}                      $side_border"
        pretty_print "$side_border To see the changelog, visit                $side_border"
        pretty_print "$side_border ${sty_und}${sty_bri_blu}https://github.com/itislu/42free/releases${sty_res}. $side_border"
        if [[ "$1" == "remind" ]]; then
            pretty_print "$side_border Run '42free --update' to update.${sty_res}           $side_border"
        fi
        pretty_print "$bottom_border"
        printed_update_info=true
    fi
}

update()
{
    if ! latest_version=$(get_latest_version_number "$1"); then
        return $?
    fi

    # Compare the latest version with the current version number
    if [[ "${current_version#v}" != "${latest_version#v}" ]]; then
        print_update_info
        if prompt_single_key "$prompt_update"; then
            bash <("$downloader" "$downloader_opts_stdout" "https://raw.githubusercontent.com/itislu/42free/main/install.sh") update; ft_exit $?
        else
            pretty_print "Not updating."
        fi
    elif [[ "$1" != "silent" ]]; then
        pretty_print "You are already using the latest version of 42free."
    fi
    return $success
}

change_max_sizes()
{
    local changed_max_size

    for dir in home sgoinfre; do
        changed_max_size=false

        # Construct variable name
        max_size_var_name="${dir}_max_size"

        # Prompt user for the maximum allowed size of the directory
        while true; do
            pretty_print "${sty_bol}Enter the maximum allowed size of your $dir directory in GB:${sty_res}"
            read -rp "> "
            if [[ $REPLY =~ ^[0-9]+$ ]]; then
                declare "$max_size_var_name=$REPLY"
                break
            fi
            pretty_print "${sty_bol}${sty_red}Invalid input. Please enter a number.${sty_res}"
        done

        # Change MAX_SIZE in all shell config files
        for config_file in "$bash_config" "$zsh_config" "$fish_config"; do
            if sed -i "/^export ${dir^^}_MAX_SIZE=/c\export ${dir^^}_MAX_SIZE=${!max_size_var_name}" "$config_file" 2>/dev/null; then
                changed_max_size=true
            fi
        done

        if $changed_max_size; then
            pretty_print "${sty_yel}The warning size for your $dir directory has been set to ${!max_size_var_name}GB.${sty_res}"
            changed_config=true
        fi
    done
}

# Remove everything added from installation in all shell config files
clean_config_files()
{
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
        if [ -f "$config_file" ]; then
            if sed -i '/^alias 42free/d' "$config_file" 2>/dev/null; then
                pretty_print "${sty_yel}42free alias removed from $shell_name.${sty_res}"
            fi
            if sed -i '/^export HOME_MAX_SIZE=/d' "$config_file" 2>/dev/null; then
                pretty_print "${sty_yel}HOME_MAX_SIZE environment variable removed from $shell_name.${sty_res}"
            fi
            if sed -i '/^export SGOINFRE_MAX_SIZE=/d' "$config_file" 2>/dev/null; then
                pretty_print "${sty_yel}SGOINFRE_MAX_SIZE environment variable removed from $shell_name.${sty_res}"
            fi
        fi
    done
}

uninstall()
{
    if prompt_with_enter "Do you wish to uninstall 42free? [${sty_bol}y${sty_res}/${sty_bol}N${sty_res}]"; then
        pretty_print "Uninstalling 42free..."
        if stderr=$(rm -f "$script_path" 2>&1); then
            pretty_print "${sty_yel}Script deleted.${sty_res}"
            # If script_dir is empty, remove it
            find "$script_dir" -maxdepth 0 -type d -empty -delete 2>/dev/null
            clean_config_files
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
reverse=false
while (( $# )); do
    case "$1" in
        -r|--reverse)
            reverse=true
            ;;
        -m|--max-size)
            change_max_sizes
            ft_exit $success
            ;;
        -u|--update)
            update
            ft_exit $?
            ;;
        -h|--help)
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

# Check if the script received any targets
if [ -z "${args[*]}" ]; then
    update silent
    args=("${default_args[@]}")
    no_user_args=true
else
    no_user_args=false
fi

print_update_info "remind"

# Check if the permissions of user's sgoinfre directory are rwx------
if ! $reverse && [ "$sgoinfre_permissions" != "drwx------" ]; then
    pretty_print "$msg_sgoinfre_permissions"
    if prompt_single_key "$prompt_change_permissions"; then
        if stderr=$(chmod 700 "$sgoinfre"); then
            pretty_print "$indicator_success The permissions of '$sgoinfre' have been changed to '${sty_bol}rwx------${sty_res}'."
        else
            pretty_print "$indicator_error Failed to change the permissions of '$sgoinfre'."
            print_stderr
            syscmd_failed=true
            if ! prompt_single_key "$prompt_continue_still"; then
                ft_exit $major_error
            fi
            pretty_print "$msg_sgoinfre_permissions_keep"
        fi
    else
        pretty_print "$msg_sgoinfre_permissions_keep"
    fi
fi

# Check which direction the script should move the directories or files
if ! $reverse; then
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
fi

# Print header
pretty_print "$header"
pretty_print "$delim_big"
echo

# Loop over all arguments
args_index=0
need_delim=false

for arg in "${args[@]}"; do
    args_index=$(( args_index + 1 ))

    # Print reminder to close all programs first in first iteration of default arguments
    if [ $args_index -eq 1 ] && $no_user_args; then
        pretty_print "$msg_close_programs"
        pretty_print "To see the manual, run '${sty_bol}42free --help${sty_res}'."
        echo
    fi

    # Print delimiter
    if $need_delim; then
        pretty_print "$delim_small"
    fi
    need_delim=true

    # Check if argument is an absolute or relative path
    if [[ "$arg" = /* ]]; then
        arg_path="$arg"
        invalid_path_msg="$indicator_error Absolute paths have to lead to a path in your ${sty_bol}home${sty_res} or ${sty_bol}sgoinfre${sty_res} directory."
    else
        arg_path="$current_dir/$arg"
        invalid_path_msg="$indicator_error The current directory is not in your ${sty_bol}home${sty_res} or ${sty_bol}sgoinfre${sty_res} directory."
    fi

    # Make sure all defined mount points of sgoinfre work with the script
    if [[ "$arg_path" = $sgoinfre_alt/* ]]; then
        sgoinfre="$sgoinfre_alt"
    else
        sgoinfre="$sgoinfre_root"
    fi
    # Update variables with updated sgoinfre path
    if ! $reverse; then
        target_base="$sgoinfre"
    else
        source_base="$sgoinfre"
    fi

    # Construct the source and target paths
    if [[ "$arg_path" = $source_base/* ]]; then
        source_path="$arg_path"
        source_subpath="${source_path#"$source_base/"}"
        target_path="$target_base/$source_subpath"
        target_subpath="${target_path#"$target_base/"}"
    elif [[ "$arg_path" = $target_base/* ]]; then
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

    # Construct useful variables from the paths
    source_dirpath=$(dirname "$source_path")
    source_basename=$(basename "$source_path")
    target_dirpath=$(dirname "$target_path")

    # Check if the source directory or file exists
    if [ ! -e "$source_path" ]; then
        # Check if the source directory or file has already been moved to sgoinfre and is missing a symbolic link
        if ! $reverse && [ -e "$target_path" ]; then
            pretty_print "'${sty_bri_yel}$source_path${sty_res}' has already been moved to sgoinfre."
            pretty_print "It is located at '${sty_bri_gre}$target_path${sty_res}'."
            if prompt_single_key "$prompt_symlink"; then
                if stderr=$(ln -sT "$target_path" "$source_path" 2>&1); then
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
            pretty_print "$indicator_error '${sty_bri_red}$source_path${sty_res}' does not exist."
            bad_input=true
        else
            need_delim=false
        fi
        continue
    fi

    # Check if the real base path of source is not actually already in target
    arg_dirpath=$(dirname "$arg_path")
    real_arg_dirpath=$(realpath "$arg_dirpath")
    real_arg_path=$(realpath "$arg_path")
    if { [[ "$arg_path" = $source_base/* ]] && [[ "$real_arg_dirpath/" != $source_base/* ]]; } ||
       { [[ "$arg_path" = $target_base/* ]] && [[ "$real_arg_dirpath/" != $target_base/* ]]; }; then
        pretty_print "$indicator_error '$source_subpath' is already in the $target_name directory."
        pretty_print "Real path: '${sty_bol}$real_arg_path${sty_res}'."
        print_skip_arg "$arg"
        bad_input=true
        continue
    fi

    # If the source directory or file has already been moved to sgoinfre, skip it
    if [ -L "$source_path" ]; then
        real_source_path=$(realpath "$source_path")
        if ! $reverse && [[ "$real_source_path" =~ ^($sgoinfre_root|$sgoinfre_alt)/ ]]; then
            if ! $no_user_args; then
                pretty_print "'${sty_bol}${sty_bri_cya}$source_subpath${sty_res}' has already been moved to sgoinfre."
                pretty_print "It is located at '$real_source_path'."
                print_skip_arg "$arg"
            else
                need_delim=false
            fi
            continue
        fi
    fi

    # If no user arguments, ask user if they want to process the current argument
    if $no_user_args && [ -e "$source_path" ]; then
        pretty_print "This will move '${sty_bol}$source_path${sty_res}' to the $target_name directory."
        if ! prompt_single_key "$prompt_continue"; then
            print_skip_arg "$arg"
            continue
        fi
    fi

    # Check if the source file is a symbolic link
    if [ -L "$source_path" ]; then
        pretty_print "$indicator_warning '${sty_bol}${sty_bri_cya}$source_path${sty_res}' is a symbolic link."
        if ! prompt_single_key "$prompt_continue_still"; then
            print_skip_arg "$arg"
            arg_skipped=true
            continue
        fi
    fi

    # Check if an existing directory or file would get replaced
    if [ -e "$target_path" ] && ! ($reverse && [ -L "$target_path" ]); then
        pretty_print "$indicator_warning '${sty_bol}$source_subpath${sty_res}' already exists in the $target_name directory."
        if ! prompt_with_enter "$prompt_replace"; then
            print_skip_arg "$arg"
            arg_skipped=true
            continue
        fi
    fi

    # Get the current sizes of the source and target base directories
    if [ -z "$target_base_size_in_bytes" ]; then
        pretty_print "Getting the current sizes of the $source_name and $target_name directories..."

        tmpfile_source_base_size="/tmp/42free~source_base_size"
        tmpfile_target_base_size="/tmp/42free~target_base_size"

        # Run parallel jobs and wait for both to finish
        du -sb "$source_base" 2>/dev/null | cut -f1 > $tmpfile_source_base_size &
        source_base_size_job=$!
        du -sb "$target_base" 2>/dev/null | cut -f1 > $tmpfile_target_base_size &
        target_base_size_job=$!
        wait_for_jobs "searching" $source_base_size_job $target_base_size_job

        # Read the sizes from the temporary files
        source_base_size_in_bytes=$(cat $tmpfile_source_base_size 2>/dev/null)
        target_base_size_in_bytes=$(cat $tmpfile_target_base_size 2>/dev/null)
        rm -f $tmpfile_source_base_size $tmpfile_target_base_size
    fi

    # Get the size of the directory or file to be moved
    pretty_print "Getting the size of $source_basename..."
    size="$(du -sh "$source_path" 2>/dev/null | cut -f1)B"
    size_in_bytes=$(du -sb "$source_path" 2>/dev/null | cut -f1)

    # Get the size of any target that will be replaced
    existing_target_size_in_bytes="$(du -sb "$target_path" 2>/dev/null | cut -f1)"

    # Convert target_max_size from GB to bytes
    max_size_in_bytes=$(( target_max_size * 1024 * 1024 * 1024 ))

    # Check if the target directory would go above its maximum recommended size
    if (( target_base_size_in_bytes + size_in_bytes - existing_target_size_in_bytes > max_size_in_bytes )); then
        pretty_print "$indicator_warning ${operation^} '${sty_bol}$source_subpath${sty_res}' would cause the ${sty_bol}$target_name${sty_res} directory to go above ${sty_bol}${target_max_size}GB${sty_res}."
        if ! prompt_single_key "$prompt_continue_still"; then
            print_skip_arg "$arg"
            arg_skipped=true
            continue
        fi
    fi

    # When moving files back to home, first remove the symbolic link
    if $reverse; then
        if [ -L "$target_path" ]; then
            rm -f "$target_path" 2>/dev/null
        fi
        if [ -L "$target_path~42free_tmp~" ]; then
            rm -f "$target_path~42free_tmp~" 2>/dev/null
        fi
    fi

    # Create the same directory structure as in source
    if ! stderr=$(mkdir -p "$target_dirpath" 2>&1); then
        pretty_print "$indicator_error Cannot create the directory structure for '$target_path'."
        print_stderr
        syscmd_failed=true
        # If not last argument, ask user if they want to continue with the other arguments
        if [ $args_index -lt $args_amount ] && ! prompt_with_enter "$prompt_continue_with_rest"; then
            pretty_print "Skipping the rest of the arguments."
            break
        fi
        continue
    fi

    # Move the files
    if ! move_files "$source_path" "$target_dirpath" "$operation"; then
        pretty_print "$indicator_error Could not fully move '${sty_bol}$source_basename${sty_res}' to '${sty_bol}$target_dirpath${sty_res}'."
        print_one_stderr
        if [ -d "$source_path" ]; then
            # Rename the directory with the files that could not be moved
            source_old="$source_path~42free-old_$(get_timestamp)~"
            if mv -T "$source_path" "$source_old" 2>/dev/null; then
                link="$source_path"
                link_create_msg="Symbolic link created and the files that could not be moved are left in '${sty_bol}$source_old${sty_res}'."
            else
                source_old="$source_path"
                link="$source_path~42free_tmp~"
                link_create_msg="Symbolic link left behind with a tmp name."
            fi

            # Create the symbolic link
            ln -sT "$target_path" "$link" 2>/dev/null
            pretty_print "$link_create_msg"

            # Calculate and print how much space was already partially moved
            leftover_size_in_bytes=$(du -sb "$source_old" 2>/dev/null | cut -f1)
            outcome_size_in_bytes=$(( size_in_bytes - leftover_size_in_bytes ))
            outcome_size="$(numfmt --to=iec --suffix=B $outcome_size_in_bytes)"
            pretty_print "${sty_bol}$outcome_size${sty_res} of ${sty_bol}$size${sty_res} $outcome."

            # Ask user if they wish to restore what was already moved or leave the partial copy
            if prompt_restore; then
                rm -f "$link" 2>/dev/null;
                mv -T "$source_old" "$source_path" 2>/dev/null
                if ! move_files "$target_path" "$source_dirpath" "restoring"; then
                    pretty_print "$indicator_error Could not fully restore '$source_basename' to '$source_dirpath'."
                    print_one_stderr
                    pretty_print "The rest of the partial copy is left in '${sty_bol}$target_path${sty_res}'."
                else
                    pretty_print "'${sty_bol}$source_basename${sty_res}' has been restored to '${sty_bol}$source_dirpath${sty_res}'."
                fi
            else
                pretty_print "Try to close all programs and move the rest from '${sty_bol}$source_old${sty_res}' manually."
            fi
        else
            pretty_print "Try to close all programs and try again."
        fi

        # If not last argument, ask user if they want to continue with the other arguments
        if [ $args_index -lt $args_amount ] && ! prompt_with_enter "$prompt_continue_with_rest"; then
            pretty_print "Skipping the rest of the arguments."
            break
        fi

        # Force recalculation of the target directory size in next iteration
        unset target_base_size_in_bytes
        continue
    fi
    pretty_print "$indicator_success '${sty_bri_yel}$source_basename${sty_res}' successfully $operation_success to '${sty_bri_gre}$target_dirpath${sty_res}'."

    if ! $reverse; then
        # Create the symbolic link
        if stderr=$(ln -sT "$target_path" "$source_path" 2>&1); then
            pretty_print "Symbolic link left behind."
        else
            pretty_print "$indicator_warning Cannot create symbolic link with name '$source_basename'."
            print_stderr
            syscmd_failed=true
            # Create the symbolic link with a tmp name
            if stderr=$(ln -sT "$target_path" "$source_path~42free_tmp~" 2>&1); then
                pretty_print "Symbolic link left behind with a tmp name."
            else
                print_stderr
            fi
            # If not last argument, ask user if they want to continue with the other arguments
            if [ $args_index -lt $args_amount ] && ! prompt_with_enter "$prompt_continue_with_rest"; then
                pretty_print "Skipping the rest of the arguments."
                break
            fi
        fi
    fi

    # Update the directory sizes
    source_base_size_in_bytes=$(( source_base_size_in_bytes - size_in_bytes ))
    target_base_size_in_bytes=$(( target_base_size_in_bytes + size_in_bytes - existing_target_size_in_bytes ))

    # Print result
    if ! $reverse; then
        outcome_color="${sty_bri_cya}"
    else
        outcome_color="${sty_bri_blu}"
    fi
    pretty_print "${sty_bol}${outcome_color}$size $outcome.${sty_res}"
    print_available_space "$source_base_size_in_bytes" "$target_base_size_in_bytes"

# Process the next argument
done

if $syscmd_failed; then
    ft_exit $major_error
elif $arg_skipped; then
    ft_exit $minor_error
elif $bad_input; then
    ft_exit $input_error
else
    ft_exit $success
fi
