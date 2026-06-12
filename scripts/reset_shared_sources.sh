#!/bin/sh
set -eu

if [ "$#" -lt 7 ]; then
	echo "usage: $0 <fetch-script> <board-root> <active-board-file> <patch-board> (<url> <ref> <dst>)..." >&2
	exit 1
fi

fetch_script="$1"
board_root="$2"
active_board_file="$3"
patch_board="$4"
shift 4

if [ $(( $# % 3 )) -ne 0 ]; then
	echo "error: expected repo arguments in <url> <ref> <dst> triples" >&2
	exit 1
fi

if [ -f "$active_board_file" ]; then
	patch_board="$(cat "$active_board_file")"
fi

autosave_dir=""

save_dirty_repo() {
	repo="$1"

	if [ ! -d "$repo/.git" ] || [ -z "$(git -C "$repo" status --short)" ]; then
		return 0
	fi

	if [ -z "$autosave_dir" ]; then
		ts="$(date +%Y%m%d-%H%M%S)"
		autosave_dir="$board_root/$patch_board/patches/autosave/$ts"
		mkdir -p "$autosave_dir"
		printf 'Autosaved before reset-sources for board: %s\n' "$patch_board" > "$autosave_dir/README.txt"
	fi

	repo_name="$(basename "$repo")"
	status_file="$autosave_dir/$repo_name.status.txt"
	patch_file="$autosave_dir/$repo_name.patch"
	untracked_list="$autosave_dir/$repo_name.untracked.txt"
	untracked_tar="$autosave_dir/$repo_name.untracked.tar.gz"

	echo "Saving dirty source tree before reset: $repo"
	git -C "$repo" status --short > "$status_file"

	if ! git -C "$repo" diff --quiet HEAD --; then
		git -C "$repo" diff --binary HEAD -- > "$patch_file"
		echo "  tracked diff: $patch_file"
	fi

	git -C "$repo" ls-files --others --exclude-standard > "$untracked_list"
	if [ -s "$untracked_list" ]; then
		tar -C "$repo" -czf "$untracked_tar" -T "$untracked_list"
		echo "  untracked archive: $untracked_tar"
	else
		rm -f "$untracked_list"
	fi
}

while [ "$#" -gt 0 ]; do
	url="$1"
	ref="$2"
	dst="$3"
	shift 3

	save_dirty_repo "$dst"

	echo "Resetting shared source tree: $dst"
	sh "$fetch_script" "$url" "$ref" "$dst"

	if [ -d "$dst/.git" ]; then
		git -C "$dst" reset --hard HEAD
		git -C "$dst" clean -fdx
	fi
done
