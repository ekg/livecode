#!/bin/bash

# Define the directories to search
root_dirs=("$HOME/.local/share/SuperCollider/downloaded-quarks/Dirt-Samples" "$HOME/sounds")

# find the wav files in all the directories (and symlinked-in directories) that are in the root_dirs
# then we cut off the wav name, cut all but the last directory, sort the results, and count with uniq -c

find -L "${root_dirs[@]}" -type f -name '*.wav' -print0 | while IFS= read -r -d '' file; do
    dirname "$file"
done | while IFS= read -r dir; do
    echo "$dir"
done | sort | uniq -c | while read -r count dir; do
    echo "$(basename $dir) ($count)"
done

# didn't work... we need to get the last part of the directory name
