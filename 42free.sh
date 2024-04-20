#!/bin/bash

current_version="0.0.2"

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
sgoinfre_root="/sgoinfre/goinfre/Perso/$USER"
sgoinfre_alt="/nfs/sgoinfre/goinfre/Perso/$USER"
sgoinfre="$sgoinfre_root"
sgoinfre_permissions=$(stat -c "%A" "$sgoinfre")

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

# Colors and styles
sty_res="\e[0m"
sty_bol="\e[1m"
sty_und="\e[4m"
sty_red="\e[31m"
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

${sty_und}Usage:${sty_res} ${sty_bol}42free${sty_res} [${sty_bol}target1 target2${sty_res} ...]
    If no arguments are given, 42free will make some suggestions.
    Target paths can be absolute or relative to your current directory.
    42free will automatically detect if an argument is the source or the destination.
    Closing all programs first will help to avoid errors during the move.

${sty_und}Options:${sty_res} You can pass options anywhere in the arguments.
    -r, --reverse  Reverse the operation and move the directories or files
                   back to their original location in home.
    -s, --suggest  Display some suggestions to move and exit.
    -h, --help     Display this help message and exit.
    -u, --update   Check for a new version of 42free.
    -v, --version  Display version information and exit.
    --             Stop interpreting options.

${sty_und}Exit codes:${sty_res}
    0: Success
    1: Input error
       An argument was invalid.
         (no arguments, unknown option, invalid path, file does not exist)
    2: Minor error
       An argument was skipped.
         (symbolic link, file conflict, no space left)
    3: Major error
       An operation failed.
         (sgoinfre permissions, update failed, move failed, restore failed, cleanup failed)

$delim_small

To contribute, report bugs or share improvement ideas, visit ${sty_und}${sty_bri_blu}https://github.com/itislu/42free${sty_res}.
\n"

msg_suggest="\
${sty_bol}Some suggestions to move:${sty_res}
   ~/.cache
   ~/.var/app/*/cache

Close all programs first to avoid errors during the move."

msg_version="\
${sty_bol}42free v$current_version${sty_res}
A script made for 42 students to take advantage of symbolic links to free up storage.
For more information, visit ${sty_und}${sty_bri_blu}https://github.com/itislu/42free${sty_res}."

msg_sgoinfre_permissions="\
$indicator_warning The permissions of your personal sgoinfre directory are not set to '${sty_bol}rwx------${sty_res}'.
They are currently set to '${sty_bol}$sgoinfre_permissions${sty_res}'.
It is ${sty_bol}highly${sty_res} recommended to change the permissions so that other students cannot access the files you will move to sgoinfre."

msg_sgoinfre_permissions_keep="Keeping the permissions of '$sgoinfre' as '$sgoinfre_permissions'."

msg_close_programs="${sty_bol}${sty_bri_yel}Close all programs first to avoid errors during the move.${sty_res}"

# Prompts
prompt_update="Do you wish to update? [${sty_bol}y${sty_res}/${sty_bol}n${sty_res}]"
prompt_continue="Do you wish to continue? [${sty_bol}y${sty_res}/${sty_bol}n${sty_res}]"
prompt_continue_still="Do you still wish to continue? [${sty_bol}y${sty_res}/${sty_bol}n${sty_res}]"
prompt_continue_with_rest="Do you wish to continue with the other arguments? [${sty_bol}y${sty_res}/${sty_bol}n${sty_res}]"
prompt_change_permissions="Do you wish to change the permissions of '$sgoinfre' to '${sty_bol}rwx------${sty_res}'? [${sty_bol}y${sty_res}/${sty_bol}n${sty_res}]"
prompt_symlink="Do you wish to create a symbolic link to it? [${sty_bol}y${sty_res}/${sty_bol}n${sty_res}]"
prompt_replace="Do you wish to continue and replace any duplicate files? [${sty_bol}y${sty_res}/${sty_bol}n${sty_res}]"

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

print_skip_arg()
{
    pretty_print "Skipping '$1'."
}

# Prompt the user for confirmation
prompt_user()
{
    pretty_print "$1"
    read -rp "> "
    if [[ ! $REPLY =~ ^[Yy](es)?$ ]]; then
        return 1
    fi
    return 0
}

prompt_restore()
{
    pretty_print "Do you wish to leave it like that? [${sty_bol}y${sty_res}/${sty_bol}n${sty_res}]"
    pretty_print "- Selecting ${sty_bol}no${sty_res} will restore what was already moved to the $target_name directory back to the $source_name directory."
    prompt_user
    return $((! $?))
}

restore_after_error()
{
    local restore_from=$1
    local restore_to=$2

    stderr=$(rsync -a --remove-source-files "$restore_from" "$restore_to/" 2>&1); ret=$?
    cleanup_empty_dirs "$restore_from"
    if [ $ret -ne 0 ]; then
        return 1
    else
        return 0
    fi
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
    if [ -z "$latest_version" ] ; then
        if [[ "$1" != "silent" ]]; then
            pretty_print "$indicator_error Cannot check for updates."
        fi
        return $major_error
    fi
    echo "$latest_version"
    return 0
}

update()
{
    if ! latest_version=$(get_latest_version_number "$1"); then
        return $?
    fi

    # Compare the latest version with the current version number
    if [[ "${latest_version#v}" != "${current_version#v}" ]]; then
        pretty_print "A new version of 42free is available."
        pretty_print "Current version: ${sty_bol}${current_version#v}${sty_res}"
        pretty_print "Latest version: ${sty_bol}${latest_version#v}${sty_res}"
        if prompt_user "$prompt_update"; then
            bash <("$downloader" "$downloader_opts_stdout" "https://raw.githubusercontent.com/itislu/42free/main/install.sh") update
            return $?
        else
            pretty_print "Not updating."
        fi
    elif [[ "$1" != "silent" ]]; then
        pretty_print "You are already using the latest version of 42free."
    fi
    return $success
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
        -s|--suggest)
            # Print some suggestions
            pretty_print "$msg_suggest"
            exit $success
            ;;
        -u|--update)
            update
            exit $?
            ;;
        -h|--help)
            # Print help message
            pretty_print "$msg_manual"
            exit $success
            ;;
        -v|--version)
            # Print version information
            pretty_print "$msg_version"
            exit $success
            ;;
        --)
            # End of options
            shift
            while (( $# )); do
                args+=("$1")
                args_amount=$((args_amount + 1))
                shift
            done
            break
            ;;
        -*)
            # Unknown option
            pretty_print "Unknown option: '$1'"
            exit $input_error
            ;;
        *)
            # Non-option argument
            args+=("$1")
            args_amount=$((args_amount + 1))
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

# Check if the permissions of user's sgoinfre directory are rwx------
if ! $reverse && [ "$sgoinfre_permissions" != "drwx------" ]; then
    pretty_print "$msg_sgoinfre_permissions"
    if prompt_user "$prompt_change_permissions"; then
        if stderr=$(chmod 700 "$sgoinfre"); then
            pretty_print "$indicator_success The permissions of '$sgoinfre' have been changed to '${sty_bol}rwx------${sty_res}'."
        else
            pretty_print "$indicator_error Failed to change the permissions of '$sgoinfre'."
            print_stderr
            syscmd_failed=true
            if ! prompt_user "$prompt_continue_still"; then
                exit $major_error
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
    max_size=30
    operation="moved"
    outcome="freed"
else
    source_base="$sgoinfre"
    source_name="sgoinfre"
    target_base="$HOME"
    target_name="home"
    max_size=5
    operation="moved back"
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
    args_index=$((args_index + 1))

    # Print reminder to close all programs first in first iteration of default arguments
    if [ $args_index -eq 1 ] && $no_user_args; then
        pretty_print "$msg_close_programs"
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
        # If the result is neither in the source nor target base directory, skip the argument
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
            if prompt_user "$prompt_symlink"; then
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
    if { [[ "$arg_path" = $source_base/* ]] && [[ "$real_arg_dirpath/" != $source_base/* ]]; } || \
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
        if ! prompt_user "$prompt_continue"; then
            print_skip_arg "$arg"
            continue
        fi
    fi

    # Check if the source file is a symbolic link
    if [ -L "$source_path" ]; then
        pretty_print "$indicator_warning '${sty_bol}${sty_bri_cya}$source_path${sty_res}' is a symbolic link."
        if ! prompt_user "$prompt_continue_still"; then
            print_skip_arg "$arg"
            arg_skipped=true
            continue
        fi
    fi

    # Check if an existing directory or file would get replaced
    if [ -e "$target_path" ] && ! ($reverse && [ -L "$target_path" ]); then
        pretty_print "$indicator_warning '${sty_bol}$source_subpath${sty_res}' already exists in the $target_name directory."
        if ! prompt_user "$prompt_replace"; then
            print_skip_arg "$arg"
            arg_skipped=true
            continue
        fi
    fi

    # Get the current size of the target directory
    if [ -z "$target_dir_size_in_bytes" ]; then
        pretty_print "Getting the current size of the $target_name directory..."
        target_dir_size_in_bytes=$(du -sb "$target_base" 2>/dev/null | cut -f1)
    fi

    # Get the size of the directory or file to be moved
    size="$(du -sh "$source_path" 2>/dev/null | cut -f1)B"
    size_in_bytes=$(du -sb "$source_path" 2>/dev/null | cut -f1)

    # Get the size of any target that will be replaced
    existing_target_size_in_bytes="$(du -sb "$target_path" 2>/dev/null | cut -f1)"

    # Convert max_size from GB to bytes
    max_size_in_bytes=$((max_size * 1024 * 1024 * 1024))

    # Check if the target directory would go above its maximum recommended size
    if (( target_dir_size_in_bytes + size_in_bytes - existing_target_size_in_bytes > max_size_in_bytes )); then
        pretty_print "$indicator_warning Moving '${sty_bol}$source_subpath${sty_res}' would cause the ${sty_bol}$target_name${sty_res} directory to go above ${sty_bol}${max_size}GB${sty_res}."
        if ! prompt_user "$prompt_continue_still"; then
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

    # Create the same directory structure as in the source
    if ! stderr=$(mkdir -p "$target_dirpath" 2>&1); then
        pretty_print "$indicator_error Cannot create the directory structure for '$target_path'."
        print_stderr
        syscmd_failed=true
        # If not last argument, ask user if they want to continue with the other arguments
        if [ $args_index -lt $args_amount ] && ! prompt_user "$prompt_continue_with_rest"; then
            pretty_print "Skipping the rest of the arguments."
            break
        fi
        continue
    fi

    # Start to move the directory or file in the background
    pretty_print "Moving '$source_basename' to '$target_dirpath'..."
    stderr=$(rsync -a --remove-source-files "$source_path" "$target_dirpath/" 2>&1) &
    rsync_pid=$!

    # Wait for rsync to finish, checking every second
    for (( i=0; i<100; i++ )); do
        if ! kill -0 $rsync_pid 2>/dev/null; then
            break
        fi
        # If rsync is still running after 10 seconds, print a message
        if [[ i -eq 10 ]]; then
            pretty_print "This can take a bit of time..."
        fi
        sleep 1
    done

    # Wait for rsync to finish
    wait $rsync_pid 2>/dev/null
    rsync_status=$?

    # Check the exit status of rsync
    if [[ $rsync_status -ne 0 ]]; then
        pretty_print "$indicator_error Could not fully move '${sty_bol}$source_basename${sty_res}' to '${sty_bol}$target_dirpath${sty_res}'."
        print_one_stderr
        syscmd_failed=true

        cleanup_empty_dirs "$source_path"
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
            outcome_size_in_bytes=$((size_in_bytes - leftover_size_in_bytes))
            outcome_size="$(numfmt --to=iec --suffix=B $outcome_size_in_bytes)"
            pretty_print "${sty_bol}$outcome_size${sty_res} of ${sty_bol}$size${sty_res} $outcome."

            # Ask user if they wish to restore what was already moved or leave the partial copy
            if prompt_restore; then
                pretty_print "Restoring '$source_basename' to '$source_dirpath'..."
                rm -f "$link" 2>/dev/null;
                mv -T "$source_old" "$source_path" 2>/dev/null
                if restore_after_error "$target_path" "$source_dirpath"; then
                    pretty_print "'${sty_bol}$source_basename${sty_res}' has been restored to '${sty_bol}$source_dirpath${sty_res}'."
                else
                    pretty_print "$indicator_error Could not fully restore '$source_basename' to '$source_dirpath'."
                    pretty_print "The rest of the partial copy is left in '${sty_bol}$target_path${sty_res}'."
                fi
            else
                pretty_print "Try to close all programs and move the rest from '${sty_bol}$source_old${sty_res}' manually."
            fi
        else
            pretty_print "Try to close all programs and try again."
        fi

        # If not last argument, ask user if they want to continue with the other arguments
        if [ $args_index -lt $args_amount ] && ! prompt_user "$prompt_continue_with_rest"; then
            pretty_print "Skipping the rest of the arguments."
            break
        fi

        # Force recalculation of the target directory size in next iteration
        unset target_dir_size_in_bytes
        continue
    fi
    pretty_print "$indicator_success '${sty_bri_yel}$source_basename${sty_res}' successfully $operation to '${sty_bri_gre}$target_dirpath${sty_res}'."
    cleanup_empty_dirs "$source_path"

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
            if [ $args_index -lt $args_amount ] && ! prompt_user "$prompt_continue_with_rest"; then
                pretty_print "Skipping the rest of the arguments."
                break
            fi
        fi
    fi

    # Update the size of the target directory
    target_dir_size_in_bytes=$((target_dir_size_in_bytes + size_in_bytes - existing_target_size_in_bytes))

    # Print result
    pretty_print "${sty_bol}$size${sty_res} $outcome."
done

if $syscmd_failed; then
    exit $major_error
elif $arg_skipped; then
    exit $minor_error
elif $bad_input; then
    exit $input_error
else
    exit $success
fi
