#!/bin/bash
set -euo pipefail

host_bin_dir="$1"
toolchain_dir="$2"
actual_bin_dir="${toolchain_dir}/x86_64-petalinux-linux/usr/bin/aarch64-xilinx-linux"

if [ ! -d "$host_bin_dir" ]; then
	echo "missing host bin dir: $host_bin_dir" >&2
	exit 1
fi

if [ ! -d "$actual_bin_dir" ]; then
	echo "missing Vitis binutils dir: $actual_bin_dir" >&2
	exit 1
fi

for actual in "$actual_bin_dir"/aarch64-xilinx-linux-*; do
	[ -e "$actual" ] || continue

	name="${actual##*/}"
	suffix="${name#aarch64-xilinx-linux-}"
	case "$suffix" in
		gcc|g++|cpp)
			continue
			;;
	esac

	ln -snf "$actual" "${host_bin_dir}/aarch64-linux-gnu-${suffix}"
done
