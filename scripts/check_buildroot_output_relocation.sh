#!/usr/bin/env bash

set -euo pipefail

buildroot_o="${1:?missing Buildroot output directory}"
stamp_file="${2:?missing stamp file}"

mkdir -p "$buildroot_o"
expected_o="$(cd "$buildroot_o" && pwd -P)"
expected_host="$expected_o/host"

mismatch_reason=""

if [ -f "$stamp_file" ]; then
    previous_o="$(cat "$stamp_file")"
    if [ "$previous_o" != "$expected_o" ]; then
        mismatch_reason="recorded output path '$previous_o' != current '$expected_o'"
    fi
fi

if [ -z "$mismatch_reason" ] && [ -f "$expected_host/bin/fakeroot" ]; then
    fakeroot_prefix="$(sed -n 's/^FAKEROOT_PREFIX=//p' "$expected_host/bin/fakeroot" | head -n1)"
    if [ -n "$fakeroot_prefix" ] && [ "$fakeroot_prefix" != "$expected_host" ]; then
        mismatch_reason="fakeroot host prefix '$fakeroot_prefix' != expected '$expected_host'"
    fi
fi

if [ -z "$mismatch_reason" ] && [ -f "$expected_host/lib/pkgconfig/zlib.pc" ]; then
    pkgconfig_prefix="$(sed -n 's/^prefix=//p' "$expected_host/lib/pkgconfig/zlib.pc" | head -n1)"
    if [ -n "$pkgconfig_prefix" ] && [ "$pkgconfig_prefix" != "$expected_host" ]; then
        mismatch_reason="host pkg-config prefix '$pkgconfig_prefix' != expected '$expected_host'"
    fi
fi

if [ -n "$mismatch_reason" ]; then
    printf 'Buildroot output relocation detected: %s\n' "$mismatch_reason" >&2
    printf 'Removing stale output tree: %s\n' "$expected_o" >&2
    rm -rf "$expected_o"
    mkdir -p "$expected_o"
fi

printf '%s\n' "$expected_o" > "$stamp_file"
