#!/bin/bash

new_path="$HOME/sgoinfre"
new_sgoinfre="/sgoinfre/$USER"
transferred_sgoinfre="$new_sgoinfre/old_data/$USER"

# Prompt the user for confirmation
# Default is 'yes', only needs y/Y key
prompt_single_key() {
    echo "$1 [Y/n]"
    read -n 1 -rp "> "
    if [[ -n "$REPLY" ]]; then
        echo
    fi
    if [[ "$REPLY" =~ ^([Yy]?)$|^$ ]]; then
        return 0
    fi
    return 1
}

# 42free users should have the SGOINFRE variable in their environment
if [ -z "$SGOINFRE" ]; then
    echo "SGOINFRE is not defined in the environment. You probably haven't used 42free yet."
    if ! prompt_single_key "Do you still want to update any outdated sgoinfre symlinks?"; then
        echo "Aborting"
        exit 0
    fi
    export SGOINFRE="/sgoinfre/goinfre/Perso/$USER"
fi

# Make sure the new sgoinfre really exists
if [ ! -d "$new_sgoinfre" ]; then
    echo "The new sgoinfre '$new_sgoinfre' does not exist!"
    exit 2
fi

# sgoinfre symlink check in home directory
if [ ! -e "$new_path" ]; then
    echo "Creating symlink $new_path -> $new_sgoinfre"
    ln -s "$new_sgoinfre" "$new_path"
elif [ ! -L "$new_path" ]; then
    echo "Error: '$new_path' already exists but is not a symlink!"
    exit 3
else
    current_target=$(readlink "$new_path")
    if [ "$current_target" != "$new_sgoinfre" ]; then
        echo "Error: $new_path points to $current_target instead of $new_sgoinfre"
        echo "The sgoinfre symlink has to link to the new sgoinfre path!"
        if ! prompt_single_key "Do you want to update it?"; then
            echo "Aborting"
            exit 4
        fi
        rm "$new_path"
        ln -s "$new_sgoinfre" "$new_path"
        echo "Symlink updated"
    fi
fi

if [ ! -L "$new_path" ]; then
    echo "Error: '$new_path' is still not a symlink!"
fi

# Find symlinks and update them
find "$HOME" -type l -lname "$SGOINFRE*" -print 2>/dev/null | while read -r symlink; do
    current_target=$(readlink "$symlink")

    # Extract the relative part of the path (everything after $SGOINFRE)
    relative_path="${current_target#"$SGOINFRE"}"

    new_target="${new_path}${relative_path}"

    echo "Updating symlink: $symlink"
    echo "  From: $current_target"
    echo "  To:   $new_path -> $(realpath "$new_target")"

rm "$symlink"
ln -s "$new_target" "$symlink"
done

echo
echo "Symlink update complete!"

# Update the SGOINFRE environment variable with 42free if it's installed
if command -v 42free &>/dev/null; then
    echo
    echo "Updating 42free..."
    yes | 42free --update
    echo "$new_path" | 42free --sgoinfre
    echo
    echo "42free successfully updated for the new sgoinfre path!"
fi


# Extract the transferred contents from the old sgoinfre in the new sgoinfre

if [ ! -d "$transferred_sgoinfre" ]; then
    exit 0
fi

echo "This last step will move all contents from $transferred_sgoinfre to $new_sgoinfre"
echo "This is very important so that all the updated symlinks will work correctly."
if ! prompt_single_key "Do you want to continue?"; then
    echo "Operation cancelled"
    exit 5
fi

# Process files, moving those without conflicts and tracking those with conflicts
moved=0
conflicts=0
conflict_list=""

while IFS= read -r -d '' item; do
    basename=$(basename "$item")
    target="$new_sgoinfre/$basename"

    if [ -e "$target" ]; then
        conflicts=$((conflicts + 1))
        conflict_list="${conflict_list}${basename}\n"
    else
        if mv -v "$item" "$new_sgoinfre/"; then
            moved=$((moved + 1))
        else
            echo "Error moving: $item"
            conflicts=$((conflicts + 1))
            conflict_list="${conflict_list}${basename}\n"
        fi
    fi
done < <(find "$transferred_sgoinfre" -maxdepth 1 ! -path "$transferred_sgoinfre" -print0)

# Print summary
echo
echo "Operation complete!"
echo "Items moved successfully: $moved"
if [ $conflicts -gt 0 ]; then
    echo "Items with conflicts (not moved): $conflicts"
    echo "The following items need manual resolution:"
    echo -e "$conflict_list"
fi

# Check if the leftover directory is empty
if [ -z "$(ls -A "$transferred_sgoinfre")" ]; then
    if prompt_single_key "$transferred_sgoinfre is now empty. Remove it?"; then
        rmdir "$transferred_sgoinfre"
        echo "Removed empty directory: $transferred_sgoinfre"
    fi
else
    echo "Warning: $transferred_sgoinfre is not fully empty yet. Please check its contents manually and move them out of the directory."
    echo "This is very important so that all the updated symlinks will work correctly."
fi
