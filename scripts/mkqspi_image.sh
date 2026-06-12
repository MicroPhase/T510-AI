#!/bin/sh
set -eu

if [ "$#" -ne 7 ]; then
	echo "usage: $0 <out.bin> <total_size> <boot.bin> <image.ub> <boot_off> <image_off> <image_max_size>" >&2
	exit 1
fi

out_bin="$1"
total_size="$2"
boot_bin="$3"
image_ub="$4"
boot_off="$5"
image_off="$6"
image_max_size="$7"

image_size=$(stat -c %s "${image_ub}")
if [ "${image_size}" -gt "$((image_max_size))" ]; then
	echo "image.ub is larger than configured QSPI image partition" >&2
	exit 1
fi

truncate -s "$((total_size))" "${out_bin}"
dd if="${boot_bin}" of="${out_bin}" bs=4M seek="$((boot_off))" oflag=seek_bytes conv=notrunc status=none
dd if="${image_ub}" of="${out_bin}" bs=4M seek="$((image_off))" oflag=seek_bytes conv=notrunc status=none
