#!/bin/sh
set -eu

if [ "$#" -lt 3 ]; then
	echo "usage: $0 <active-board-file> <board> <repo>..." >&2
	exit 1
fi

active_file="$1"
board="$2"
shift 2

if [ -f "$active_file" ]; then
	active_board="$(cat "$active_file")"
	if [ "$active_board" != "$board" ]; then
		cat >&2 <<EOF
error: shared source trees are marked for board '$active_board', not '$board'.

The kernel, U-Boot and Buildroot source trees are shared between boards, and
board-specific patches are applied in-place. Reset them before switching boards:

  make BOARD=$board reset-sources

If you intentionally want to reuse the current patched source trees, remove
$active_file manually after reviewing the diffs.
EOF
		exit 1
	fi
	exit 0
fi

dirty_repos=""
for repo in "$@"; do
	if [ -d "$repo/.git" ] && [ -n "$(git -C "$repo" status --short)" ]; then
		dirty_repos="${dirty_repos}
  $repo"
	fi
done

if [ -n "$dirty_repos" ]; then
	cat >&2 <<EOF
error: shared source trees are dirty and no active board marker exists.

Dirty repositories:${dirty_repos}

Run this once before building '$board':

  make BOARD=$board reset-sources

reset-sources saves dirty shared source changes under
board/<source-board>/patches/autosave/ before cleaning. If no active board
marker exists, pass SOURCE_PATCH_BOARD=<previous-board> to classify the autosave
correctly.
EOF
	exit 1
fi

mkdir -p "$(dirname "$active_file")"
printf '%s\n' "$board" > "$active_file"
