#!/bin/bash

# Exit codes
success=0
no_targets=1
unknown_option=2

current_dir=$(pwd)
sgoinfre="/nfs/sgoinfre/goinfre/Perso/$USER"

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
            echo -e "\e[1mSome suggestions to move:\e[0m"
            echo -e "    - ~/.cache"
            echo -e "    - ~/.local/share/Trash"
            echo -e "    - ~/.var/app/*/cache"
            exit $success
            ;;
        -h|--help)
            # Print help message
            echo -e "\e[1mMove directories or files to free up storage.\e[0m"
            echo -e "The files get moved from $HOME"
            echo -e "                      to $sgoinfre."
            echo
            echo -e "\e[4mUsage:\e[0m \e[1m42free target1 [target2 ...]\e[0m"
            echo -e "    The target paths can be absolute or relative to your current directory."
            echo -e "    You can only move directories and files inside of your home and sgoinfre directories."
            echo -e "    42free will automatically detect if the given argument is the source or the destination."
            echo
            echo -e "\e[4mOptions:\e[0m You can pass options anywhere in the arguments."
            echo -e "    -r, --reverse  Reverse the operation and move the directories or files"
            echo -e "                   back to their original location in home."
            echo -e "    -s, --suggest  Display some suggestions to move and exit."
            echo -e "    -h, --help     Display this help message and exit."
            echo -e "    -v, --version  Display version information and exit."
            echo -e "    --             Stop interpreting options."
            echo
            echo -e "\e[4mExit codes:\e[0m"
            echo -e "    0: Success"
            echo -e "    1: No targets provided"
            echo -e "    2: Unknown option"
            echo
            echo -e "To contribute, report bugs or share improvement ideas,"
            echo -e "visit \e[4;34mhttps://github.com/itislu/42free\e[0m."
            echo
            exit $success
            ;;
        -v|--version)
            # Print version information
            echo -e "\e[1m42free v1.0.0\e[0m"
            echo -e "A script made for 42 students to move directories or files to free up storage."
            echo -e "For more information, visit \e[4;34mhttps://github.com/itislu/42free\e[0m."
            exit $success
            ;;
        --)
            # End of options
            shift
            break
            ;;
        -*)
            # Unknown option
            echo "Unknown option: $1"
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
    echo -e "\e[1;31mNo targets provided.\e[0m"
    echo -e "Please provide the directories or files to move as arguments."
    echo -e "\nFor more information how to use this script, run \e[1m42free -h\e[0m."
    exit $no_targets
fi

# Loop over all arguments
for arg in "$@"
do
    # Check if argument is an absolute or relative path
    if [[ "$arg" = /* ]]; then
        arg_path="$arg"
        error_msg="Absolute paths have to lead to a path in your \e[1mhome\e[0m or \e[1msgoinfre\e[0m directory. Skip."
    else
        arg_path="$current_dir/$arg"
        error_msg="The current directory is not in your \e[1mhome\e[0m or \e[1msgoinfre\e[0m directory. Skip."
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
        echo -e "$error_msg"
        continue
    fi

    # Check if the source directory or file exists
    if [ ! -e "$source_path" ]; then
        echo -e "\e[1;31m$source_path\e[0m does not exist."
        continue
    fi

    # Get the size of the directory or file to be moved
    size="$(du -sh "$source_path" | cut -f1)B"
    size_in_bytes=$(du -sb "$source_path" | cut -f1)

    # Get the available space in the target directory
    available_space_in_bytes=$(df --output=avail -B1 "$target_base" | tail -n1)

    # Check if the target directory would go above its maximum recommended size after moving
    if (( available_space_in_bytes - size_in_bytes < max_size * 1024**3 )); then
        echo -e "This operation would cause the \e[1m$target_name\e[0m directory"
        echo -e "to go above \e[1m${max_size}GB\e[0m."
        echo -e "Do you still wish to continue? (y/n)"
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
        echo -e "\e[1;31mError moving $source_path to $target_path.\e[0m"
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
    echo -e "\e[93m$source_path\e[0m successfully $operation"
    echo -e "to \e[92m$target_path\e[0m."
    echo -e "\e[1m$size\e[0m $outcome."
done
