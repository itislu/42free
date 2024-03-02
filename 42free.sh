#!/bin/bash

current_dir=$(pwd)
sgoinfre="/nfs/sgoinfre/goinfre/Perso/$USER"

# Exit codes
success=0
no_targets=1
unknown_option=2

# Colors and styles
sty_res="\e[0m"
sty_bol="\e[1m"
sty_und="\e[4m"
sty_red="\e[31m"
sty_blu="\e[34m"
sty_bri_gre="\e[92m"
sty_bri_yel="\e[93m"

manual_msg="\
${sty_bol}Move directories or files to free up storage.${sty_res}
The files get moved from '$HOME' to '$sgoinfre'.

${sty_und}Usage:${sty_res} ${sty_bol}42free target1 [target2 ...]${sty_res}
    The target paths can be absolute or relative to your current directory.
    You can only move directories and files inside of your home and sgoinfre directories.
    42free will automatically detect if the given argument is the source or the destination.

${sty_und}Options:${sty_res} You can pass options anywhere in the arguments.
    -r, --reverse  Reverse the operation and move the directories or files
                   back to their original location in home.
    -s, --suggest  Display some suggestions to move and exit.
    -h, --help     Display this help message and exit.
    -v, --version  Display version information and exit.
    --             Stop interpreting options.

${sty_und}Exit codes:${sty_res}
    0: Success
    1: No targets provided
    2: Unknown option

To contribute, report bugs or share improvement ideas, visit ${sty_und}${sty_blu}https://github.com/itislu/42free${sty_res}.
"

suggest_msg="\
${sty_bol}Some suggestions to move:${sty_res}
    - ~/.cache
    - ~/.local/share/Trash
    - ~/.var/app/*/cache"

version_msg="\
${sty_bol}42free v1.0.0${sty_res}
A script made for 42 students to move directories or files to free up storage.
For more information, visit ${sty_und}${sty_blu}https://github.com/itislu/42free${sty_res}."

no_targets_msg="\
${sty_bol}${sty_red}No targets provided.${sty_res}
Please provide the directories or files to move as arguments.

For more information how to use this script, run '${sty_bol}42free -h${sty_res}'."

no_space_prompt_msg="\
${sty_bol}${sty_red}This operation would cause the '${sty_res}${sty_bol}$target_name${sty_bol}${sty_red}' directory to go above ${sty_res}${sty_bol}${max_size}GB${sty_bol}${sty_red}.${sty_res}
${sty_bol}Do you still wish to continue? (y/n)${sty_res}"

success_msg="\
'${sty_bri_yel}$source_path${sty_res}' successfully $operation to '${sty_bri_gre}$target_path${sty_res}'.
${sty_bol}$size${sty_res} $outcome."

# Automatically detects the size of the terminal window and preserves word boundaries at the edges
pretty_print()
{
    printf "%b" "$1" | fmt -sw $(tput cols)
}

# Process options
args=()
reverse=false
while (( $# )); do
    case "$1" in
        -r|--reverse)
            reverse=true
            ;;
        -s|--suggest)
            # Print some suggestions
            pretty_print "$suggest_msg"
            ;;
        -h|--help)
            # Print help message
            pretty_print "$manual_msg"
            exit $success
            ;;
        -v|--version)
            # Print version information
            pretty_print "$version_msg"
            exit $success
            ;;
        --)
            # End of options
            shift
            break
            ;;
        -*)
            # Unknown option
            pretty_print "Unknown option: '$1'"
            exit $unknown_option
            ;;
        *)
            # Non-option argument
            args+=("$1")
            ;;
    esac
    shift
done

# Set positional parameters to non-option arguments
set -- "${args[@]}"

# Check which direction the script should move the directories or files
if ! $reverse; then
    source_base="$HOME"
    target_base="$sgoinfre"
    target_name="sgoinfre"
    max_size=30
    operation="moved"
    outcome="freed"
else
    source_base="$sgoinfre"
    target_base="$HOME"
    target_name="home"
    max_size=5
    operation="moved back"
    outcome="reclaimed"
fi

# Check if the script received any targets
if [ $# -eq 0 ]; then
    pretty_print "$no_targets_msg"
    exit $no_targets
fi

# Loop over all arguments
for arg in "$@"
do
    # Check if argument is an absolute or relative path
    if [[ "$arg" = /* ]]; then
        arg_path="$arg"
        invalid_path_msg="Absolute paths have to lead to a path in your ${sty_bol}home${sty_res} or ${sty_bol}sgoinfre${sty_res} directory. Skip."
    else
        arg_path="$current_dir/$arg"
        invalid_path_msg="The current directory is not in your ${sty_bol}home${sty_res} or ${sty_bol}sgoinfre${sty_res} directory. Skip."
    fi

    # Construct the source and target paths
    if [[ "$arg_path" = $source_base/* ]]; then
        source_path="$arg_path"
        target_path="$target_base/${source_path#"$source_base/"}"
    elif [[ "$arg_path" = $target_base/* ]]; then
        target_path="$arg_path"
        source_path="$source_base/${target_path#"$target_base/"}"
    else
        # If the result is neither in the source nor target base directory, skip the argument
        pretty_print "$invalid_path_msg"
        continue
    fi

    # Check if the source directory or file exists
    if [ ! -e "$source_path" ]; then
        pretty_print "'${sty_bol}${sty_red}$source_path${sty_res}' does not exist."
        continue
    fi

    # Get the size of the directory or file to be moved
    size="$(du -sh "$source_path" | cut -f1)B"
    size_in_bytes=$(du -sb "$source_path" | cut -f1)

    # Get the available space in the target directory
    available_space_in_bytes=$(df --output=avail -B1 "$target_base" | tail -n1)

    # Check if the target directory would go above its maximum recommended size after moving
    if (( available_space_in_bytes - size_in_bytes < max_size * 1024**3 )); then
        pretty_print "$no_space_prompt_msg"
        read -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            continue
        fi
    fi

    # Create the parent directories for the target path
    mkdir -p "$(dirname "$target_path")"

    # Check if the target path is a symbolic link
    if $reverse && [ -L "$target_path" ]; then
        rm "$target_path"
    fi

    # Move the directory or file
    if ! mv "$source_path" "$target_path"; then
        pretty_print "${sty_bol}${sty_red}Error moving '$source_path' to '$target_path'.${sty_res}"
        continue
    fi

    # If reverse flag is not active, leave a symbolic link behind
    if ! $reverse; then
        ln -s "$target_path" "$source_path"
    else
      # If reverse flag is active, delete empty parent directories
        first_dir_after_base="$source_base/${arg%%/*}"
        find "$first_dir_after_base" -type d -empty -delete 2> /dev/null
        if [ -d "$first_dir_after_base" ] && [ -z "$(ls -A "$first_dir_after_base")" ]; then
            rmdir "$first_dir_after_base"
        fi
    fi

    # Print success message
    pretty_print "$success_msg"
done
