#!/usr/bin/env bash
# link.sh - create symlinks for assignment1..3 and project* dirs into a destination
# Usage: link.sh [-f] DEST_DIR [SRC_DIR]
#   -f : force replacement of existing entries without prompting
# If SRC_DIR is omitted, the script assumes the repository root is the parent of the script directory.

set -euo pipefail

FORCE=0
while getopts ":fh" opt; do
    case $opt in
        f) FORCE=1 ;;
        h) echo "Usage: $0 [-f] DEST_DIR [SRC_DIR]"; exit 0 ;;
        *) echo "Usage: $0 [-f] DEST_DIR [SRC_DIR]"; exit 1 ;;
    esac
done
shift $((OPTIND-1))

if [ $# -lt 1 ]; then
    echo "Error: destination directory required"
    echo "Usage: $0 [-f] DEST_DIR [SRC_DIR]"
    exit 1
fi

DEST_DIR="$1"
SRC_DIR="${2:-$(cd "$(dirname "$0")/.." && pwd)}"

# If repository has a `src/` directory and assignments were moved there, use it
# as the base source directory. Otherwise fall back to the provided/default
# repository root.
if [ -d "$SRC_DIR/src" ]; then
    BASE_SRC="$SRC_DIR/src"
else
    BASE_SRC="$SRC_DIR"
fi

# ensure DEST_DIR exists
mkdir -p "$DEST_DIR"

# enable nullglob for project* expansion
shopt -s nullglob

items=(assignment1 assignment2 assignment3)
for d in "$BASE_SRC"/project*; do
    if [ -d "$d" ]; then
        items+=("$(basename "$d")")
    fi
done

if [ ${#items[@]} -eq 0 ]; then
    echo "No matching items to link."
    exit 0
fi

for name in "${items[@]}"; do
    src="$BASE_SRC/$name"
    dest="$DEST_DIR/$name"

    if [ ! -e "$src" ]; then
        echo "Skipping missing source: $src"
        continue
    fi

    if [ -L "$dest" ]; then
        # existing symlink
        current_target="$(readlink -f "$dest" || true)"
        src_resolved="$(readlink -f "$src" || true)"
        if [ "$current_target" = "$src_resolved" ]; then
            echo "Link exists and is correct: $dest -> $src"
            continue
        fi
        if [ "$FORCE" -eq 0 ]; then
            read -r -p "Replace existing symlink $dest (points to $current_target)? [y/N] " ans
            case "$ans" in [yY][eE][sS]|[yY]) ;;
                *) echo "Skipping $dest"; continue ;;
            esac
        fi
        rm -f "$dest"
    elif [ -e "$dest" ]; then
        # exists and is not a symlink
        if [ "$FORCE" -eq 0 ]; then
            read -r -p "Path exists and is not a symlink: $dest. Replace it? [y/N] " ans
            case "$ans" in [yY][eE][sS]|[yY]) ;;
                *) echo "Skipping $dest"; continue ;;
            esac
        fi
        rm -rf "$dest"
    fi

    # create symlink (use absolute source so edits here propagate)
    ln -s "$src" "$dest"
    echo "Linked: $dest -> $src"
done