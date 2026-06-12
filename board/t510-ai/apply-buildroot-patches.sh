#!/bin/bash
# Apply Buildroot patches for T510-AI board

set -e

BOARD_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_DIR="$BOARD_DIR/patches/buildroot"
BUILDROOT_DIR="$1"

if [ -z "$BUILDROOT_DIR" ]; then
    echo "Usage: $0 <buildroot-source-dir>"
    exit 1
fi

if [ ! -d "$BUILDROOT_DIR" ]; then
    echo "Error: Buildroot directory '$BUILDROOT_DIR' does not exist"
    exit 1
fi

if [ -d "$PATCH_DIR" ]; then
    echo "Looking for patches in: $PATCH_DIR"

    for patch in $(find "$PATCH_DIR" -name "*.patch" -type f | sort); do
        echo "Applying patch: $(basename "$patch")"

        if patch -p1 -N --dry-run -d "$BUILDROOT_DIR" < "$patch" >/dev/null 2>&1; then
            patch -p1 -d "$BUILDROOT_DIR" < "$patch"
            echo "  -> Successfully applied"
        else
            echo "  -> Already applied or failed (skipping)"
        fi
    done
else
    echo "No patch directory found: $PATCH_DIR"
fi

echo "Buildroot patches applied successfully"
