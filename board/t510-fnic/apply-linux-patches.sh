#!/bin/bash
# Apply Linux kernel patches for T510_FNIC board

set -e

BOARD_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_DIR="$BOARD_DIR/patches/linux"
KERNEL_DIR="$1"

if [ -z "$KERNEL_DIR" ]; then
    echo "Usage: $0 <kernel-source-dir>"
    exit 1
fi

if [ ! -d "$KERNEL_DIR" ]; then
    echo "Error: Kernel directory '$KERNEL_DIR' does not exist"
    exit 1
fi

if [ -d "$PATCH_DIR" ]; then
    echo "Looking for patches in: $PATCH_DIR"
    
    # Sort patches numerically
    for patch in $(find "$PATCH_DIR" -name "*.patch" -type f | sort); do
        echo "Applying patch: $(basename "$patch")"
        
        # Check if patch has already been applied
        if patch -p1 -N --dry-run -d "$KERNEL_DIR" < "$patch" >/dev/null 2>&1; then
            patch -p1 -d "$KERNEL_DIR" < "$patch"
            echo "  -> Successfully applied"
        else
            echo "  -> Already applied or failed (skipping)"
        fi
    done
else
    echo "No patch directory found: $PATCH_DIR"
fi

echo "Linux kernel patches applied successfully"
