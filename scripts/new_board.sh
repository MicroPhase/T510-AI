#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	echo "usage: $0 <board-name> [board-description]" >&2
	exit 1
fi

BOARD_NAME="$1"
BOARD_DESC="${2:-${BOARD_NAME} firmware builder}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOARD_DIR="${ROOT_DIR}/board/${BOARD_NAME}"
TEMPLATE_DIR="${ROOT_DIR}/templates/new-board"

if [ -e "${BOARD_DIR}" ]; then
	echo "board '${BOARD_NAME}' already exists" >&2
	exit 1
fi

mkdir -p \
	"${BOARD_DIR}/boot" \
	"${BOARD_DIR}/linux" \
	"${BOARD_DIR}/u-boot" \
	"${BOARD_DIR}/buildroot/rootfs-overlay/etc"

render() {
	local src="$1"
	local dst="$2"

	sed \
		-e "s|@BOARD@|${BOARD_NAME}|g" \
		-e "s|@BOARD_DESC@|${BOARD_DESC}|g" \
		"${src}" > "${dst}"
}

render "${TEMPLATE_DIR}/board.mk.in" "${BOARD_DIR}/board.mk"
render "${TEMPLATE_DIR}/system-user.dtsi.in" "${BOARD_DIR}/linux/system-user.dtsi"
render "${TEMPLATE_DIR}/uEnv.txt.in" "${BOARD_DIR}/boot/uEnv.txt"
render "${TEMPLATE_DIR}/u-boot.fragment.in" "${BOARD_DIR}/u-boot/fragment.config"
render "${TEMPLATE_DIR}/buildroot-defconfig.in" "${BOARD_DIR}/buildroot/defconfig"
render "${TEMPLATE_DIR}/post-build.sh.in" "${BOARD_DIR}/buildroot/post-build.sh"
render "${TEMPLATE_DIR}/issue.in" "${BOARD_DIR}/buildroot/rootfs-overlay/etc/issue"
render "${TEMPLATE_DIR}/motd.in" "${BOARD_DIR}/buildroot/rootfs-overlay/etc/motd"

echo "created board scaffold:"
echo "  ${BOARD_DIR}"
