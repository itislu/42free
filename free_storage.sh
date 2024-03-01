#!/bin/bash

# Check if the first argument is -h or --help
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo -e "\e[1mMove directories or files to free up storage.\e[0m"
    echo -e "\e[4mUsage:\e[0m $0 [-r|--reverse] target1 [target2 ...]"
    echo -e "    The target paths have to be relative to your home / sgoinfre directory or"
    echo -e "    have to start with the path to your home / sgoinfre directory."
    echo -e "\n\e[4mOptions:\e[0m"
    echo -e "    -r, --reverse  Reverse the operation and move the directories or files"
    echo -e "                   back to their original location."
    echo -e "    -h, --help     Display this help message."
    echo
    exit 0
fi

# Check if the first argument is -r or --reverse
if [ "$1" = "-r" ] || [ "$1" = "--reverse" ]; then
    reverse=true
    source_base="/nfs/sgoinfre/goinfre/Perso/$USER/"
    target_base="/nfs/homes/$USER/"
    source_name="sgoinfre"
    target_name="home"
    max_size=5
    operation="moved back"
    outcome="reclaimed"
    shift
else
    reverse=false
    source_base="/nfs/homes/$USER/"
    target_base="/nfs/sgoinfre/goinfre/Perso/$USER/"
    source_name="home"
    target_name="sgoinfre"
    max_size=30
    operation="moved"
    outcome="freed"
fi

# Check if the script received any targets
if [ $# -eq 0 ]; then
    echo -e "\e[1;31mNo targets provided.\e[0m"
    echo -e "Please provide the directories or files to move as arguments."
    echo -e "\nFor more information how to use this script, run \e[1m$0 -h\e[0m."
    exit 1
fi

# Loop over all arguments
for arg in "$@"
do
    # Check if the argument is an absolute path and construct the source and target paths
    if [[ "$arg" = $source_base* ]]; then
        source_path="$arg"
        target_path="${target_base}${arg#$source_base}"
    elif [[ "$arg" = /* ]]; then
        echo -e "Absolute paths have to start with the path to your \e[1m$source_name\e[0m directory."
        continue
    else
        source_path="${source_base}${arg}"
        target_path="${target_base}${arg}"
    fi

    # Check if the source directory or file exists
    if [ ! -e "$source_path" ]; then
        echo -e "\e[1;31m$source_path\e[0m does not exist."
        if [[ "$arg" != /* ]]; then
            echo -e "Please provide the path relative to your \e[1m$source_name\e[0m directory."
        fi
        continue
    fi

    # Get the size of the directory or file to be moved
    size="$(du -sh $source_path | cut -f1)B"
    size_in_bytes=$(du -sb $source_path | cut -f1)

    # Get the available space in the target directory
    available_space_in_bytes=$(df --output=avail -B1 "$target_base" | tail -n1)

    # Check if the target directory would go above its maximum recommended size after moving
    if (( available_space_in_bytes - size_in_bytes < $max_size * 1024**3 )); then
        echo -e "This operation would cause the \e[1m$target_name\e[0m directory to go above \e[1m${max_size}GB\e[0m."
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
    mv $source_path $target_path
    if [ $? -ne 0 ]; then
        echo -e "\e[1;31mError moving $source_path to $target_path.\e[0m"
        continue
    fi

    # If reverse flag is not active, create a symbolic link
    if ! $reverse; then
        ln -s $target_path $source_path
    else
      # If reverse flag is active, delete empty parent directories
        first_dir_after_base="${source_base}${arg%%/*}"
        find "$first_dir_after_base" -type d -empty -delete
        if [ -d "$first_dir_after_base" ] && [ -z "$(ls -A "$first_dir_after_base")" ]; then
            rmdir "$first_dir_after_base"
        fi
    fi

    # Print success message
    if ! $reverse; then
        echo -e "\e[93m$source_path\e[0m successfully $operation."
        echo -e "\e[1m$size\e[0m $outcome."
    else
        echo -e "\e[92m$target_path\e[0m successfully $operation."
        echo -e "\e[1m$size\e[0m $outcome."
    fi
done
