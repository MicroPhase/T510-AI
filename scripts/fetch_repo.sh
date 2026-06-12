#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
	echo "usage: $0 <url> <ref> <dst>" >&2
	exit 1
fi

url="$1"
ref="$2"
dst="$3"

if [ -d "${dst}/.git" ]; then
	git -C "${dst}" remote set-url origin "${url}"
	if git -C "${dst}" fetch --force --depth 1 --no-tags origin "refs/heads/${ref}:refs/remotes/origin/${ref}" 2>/dev/null; then
		target="refs/remotes/origin/${ref}"
	elif git -C "${dst}" fetch --force --depth 1 --no-tags origin "refs/tags/${ref}:refs/tags/${ref}" 2>/dev/null; then
		target="refs/tags/${ref}"
	else
		echo "error: ref '${ref}' not found in ${url}" >&2
		exit 1
	fi
else
	git clone --depth 1 --branch "${ref}" --single-branch "${url}" "${dst}"
	target="${ref}"
fi

git -C "${dst}" checkout --force "${target}"
git -C "${dst}" submodule sync --recursive
git -C "${dst}" submodule update --init --recursive
