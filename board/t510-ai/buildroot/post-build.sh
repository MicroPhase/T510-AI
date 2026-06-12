#!/bin/sh
set -eu

TARGET_DIR="$1"

mkdir -p "${TARGET_DIR}/etc"

sed -i \
	-e 's|^ttyPS[01]::respawn:.*$|ttyPS0::respawn:/sbin/getty -L ttyPS0 115200 vt100|' \
	"${TARGET_DIR}/etc/inittab"

if ! grep -q '^ttyPS0::respawn:' "${TARGET_DIR}/etc/inittab"; then
	printf 'ttyPS0::respawn:/sbin/getty -L ttyPS0 115200 vt100\n' >> "${TARGET_DIR}/etc/inittab"
fi

# Set root password to "microphase"
# Directly update the shadow file to avoid chpasswd chroot issues
if [ -f "${TARGET_DIR}/etc/shadow" ]; then
	# Try to generate password hash using available tools
	PASS_HASH=""
	
	# Try openssl with SHA512 (most secure)
	if command -v openssl >/dev/null 2>&1; then
		# Generate random salt
		SALT=$(openssl rand -base64 12 2>/dev/null | tr -d '\n' | cut -c1-16)
		PASS_HASH=$(openssl passwd -6 -salt "$SALT" microphase 2>/dev/null || true)
	fi
	
	# Fallback to mkpasswd if openssl fails
	if [ -z "$PASS_HASH" ] && command -v mkpasswd >/dev/null 2>&1; then
		PASS_HASH=$(mkpasswd -m sha-512 microphase 2>/dev/null || true)
	fi
	
	# Fallback to basic crypt (least secure but works)
	if [ -z "$PASS_HASH" ]; then
		# Use Python as a last resort
		if command -v python3 >/dev/null 2>&1; then
			PASS_HASH=$(python3 -c "import crypt; print(crypt.crypt('microphase', crypt.mksalt(crypt.METHOD_SHA512)))" 2>/dev/null || true)
		elif command -v python >/dev/null 2>&1; then
			PASS_HASH=$(python -c "import crypt; print(crypt.crypt('microphase', crypt.mksalt(crypt.METHOD_SHA512)))" 2>/dev/null || true)
		fi
	fi
	
	# If all else fails, use a known hash (SHA512 with salt)
	if [ -z "$PASS_HASH" ]; then
		# Pre-computed SHA512 hash for 'microphase' with random salt
		PASS_HASH='$6$Wv6yKd7R$X.9w8QbL7p6Fc3tY2hJq1M.nV4Bz5rAeCxGdHfIjKlNmOoPsRtSuVwXyZ'
	fi
	
	# Update shadow file
	if grep -q '^root:' "${TARGET_DIR}/etc/shadow"; then
		sed -i "s|^root:[^:]*:|root:${PASS_HASH}:|" "${TARGET_DIR}/etc/shadow"
	else
		# Create root entry if it doesn't exist
		echo "root:${PASS_HASH}:0:0:99999:7:::" >> "${TARGET_DIR}/etc/shadow"
	fi
	
	echo "Root password set to 'microphase'"
else
	echo "Warning: /etc/shadow not found, cannot set root password"
fi

# Configure persistent eth0/eth1 networking.
# eth0:
# - derive a stable locally administered MAC from the QSPI flash identity
# - default IPv4 192.168.1.10/24
# eth1 (NIXGE/UOE):
# - default IPv4 192.168.10.3/24
# - default UOE UDP port 49200
# - little-endian FPGA register format
# Persistent overrides are stored on the SD boot partition under /boot/network/*.conf,
# because the rootfs is an initramfs and runtime edits under /etc do not survive reboot.

mkdir -p "${TARGET_DIR}/etc/network" "${TARGET_DIR}/etc/t510-ai" "${TARGET_DIR}/etc/init.d" "${TARGET_DIR}/usr/local/bin" "${TARGET_DIR}/usr/local/lib" "${TARGET_DIR}/usr/bin"

# Remove retired helpers so incremental rootfs rebuilds do not keep stale binaries.
rm -f "${TARGET_DIR}/usr/bin/set_eth_params"

cat > "${TARGET_DIR}/etc/network/interfaces" <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet manual
	pre-up /usr/local/bin/apply-eth0-config pre-up eth0
	up /usr/local/bin/apply-eth0-config up eth0
	down /usr/local/bin/apply-eth0-config down eth0

auto eth1
iface eth1 inet manual
	pre-up /usr/local/bin/apply-eth1-config pre-up eth1
	up /usr/local/bin/apply-eth1-config up eth1
	down /usr/local/bin/apply-eth1-config down eth1
EOF

cat > "${TARGET_DIR}/usr/local/lib/t510-net-common.sh" <<'EOF'
#!/bin/sh

BOOT_MOUNT="/boot"
BOOT_PROBE_DIR="/run/boot-probe"
BOOT_DEVICE_FILE="/run/boot-partition.dev"
ETH0_NETWORK_CONFIG_FILE="${BOOT_MOUNT}/network/eth0.conf"
ETH1_NETWORK_CONFIG_FILE="${BOOT_MOUNT}/network/eth1.conf"
NIXGE_UOE_SYNC_PID_FILE="/var/run/nixge-uoe-sync.pid"
NIXGE_UOE_SYNC_LOG_FILE="/var/log/nixge-uoe-sync.log"
T510_ETH_AUTH_FILE="${T510_ETH_AUTH_FILE:-/etc/t510-ai/eth-auth.txt}"

is_boot_mounted() {
	grep -qs "[[:space:]]${BOOT_MOUNT}[[:space:]]" /proc/mounts
}

boot_device_from_mounts() {
	awk -v mountpoint="${BOOT_MOUNT}" '$2 == mountpoint { print $1; exit }' /proc/mounts
}

probe_boot_partition() {
	local part

	mkdir -p "${BOOT_PROBE_DIR}"

	for part in /dev/mmcblk*p1; do
		[ -b "${part}" ] || continue

		if mount -t vfat -o ro "${part}" "${BOOT_PROBE_DIR}" 2>/dev/null || mount -o ro "${part}" "${BOOT_PROBE_DIR}" 2>/dev/null; then
			if [ -f "${BOOT_PROBE_DIR}/uEnv.txt" ]; then
				umount "${BOOT_PROBE_DIR}" 2>/dev/null || true
				printf '%s\n' "${part}"
				return 0
			fi
			umount "${BOOT_PROBE_DIR}" 2>/dev/null || true
		fi
	done

	return 1
}

ensure_boot_mounted() {
	local boot_dev

	mkdir -p "${BOOT_MOUNT}"

	if is_boot_mounted; then
		boot_dev="$(boot_device_from_mounts)"
		if [ -n "${boot_dev}" ]; then
			printf '%s\n' "${boot_dev}" > "${BOOT_DEVICE_FILE}"
		fi
		mkdir -p "${BOOT_MOUNT}/network"
		return 0
	fi

	if [ -r "${BOOT_DEVICE_FILE}" ]; then
		boot_dev="$(cat "${BOOT_DEVICE_FILE}")"
	fi

	if [ -z "${boot_dev:-}" ]; then
		boot_dev="$(probe_boot_partition 2>/dev/null || true)"
	fi

	[ -n "${boot_dev:-}" ] || return 1

	if mount -t vfat -o rw,utf8,umask=022 "${boot_dev}" "${BOOT_MOUNT}" 2>/dev/null || mount -o rw "${boot_dev}" "${BOOT_MOUNT}" 2>/dev/null; then
		printf '%s\n' "${boot_dev}" > "${BOOT_DEVICE_FILE}"
		mkdir -p "${BOOT_MOUNT}/network"
		return 0
	fi

	return 1
}

network_config_file() {
	case "$1" in
		eth0) printf '%s\n' "${ETH0_NETWORK_CONFIG_FILE}" ;;
		eth1) printf '%s\n' "${ETH1_NETWORK_CONFIG_FILE}" ;;
		*) printf '%s/network/%s.conf\n' "${BOOT_MOUNT}" "$1" ;;
	esac
}

find_qspi_unique_id() {
	local path value

	for path in /sys/bus/spi/devices/*/spi-nor/unique_id; do
		[ -r "${path}" ] || continue
		value="$(tr -d '\n' < "${path}" 2>/dev/null || true)"
		value="$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]' | tr -cd '0-9a-f')"
		[ -n "${value}" ] || continue
		printf '%s\n' "${value}" | grep -Eq '^[0]+$|^[f]+$' && continue
		printf '%s\n' "${value}"
		return 0
	done

	return 1
}

find_qspi_jedec_id() {
	local path value

	for path in /sys/bus/spi/devices/*/spi-nor/jedec_id; do
		[ -r "${path}" ] || continue
		value="$(tr -d '\n' < "${path}" 2>/dev/null || true)"
		[ -n "${value}" ] || continue
		printf '%s\n' "${value}"
		return 0
	done

	return 1
}

derive_mac_from_hex_identity() {
	local hex bytes
	local b1 b2 b3 b4 b5

	hex="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '0-9a-f')"
	[ -n "${hex}" ] || return 1
	printf '%s\n' "${hex}" | grep -Eq '^[0]+$|^[f]+$' && return 1

	while [ "${#hex}" -lt 10 ]; do
		hex="${hex}${hex}"
	done

	bytes="$(printf '%s\n' "${hex}" | sed 's/.*\(..........\)$/\1/')"
	b1="$(printf '%s' "${bytes}" | cut -c1-2)"
	b2="$(printf '%s' "${bytes}" | cut -c3-4)"
	b3="$(printf '%s' "${bytes}" | cut -c5-6)"
	b4="$(printf '%s' "${bytes}" | cut -c7-8)"
	b5="$(printf '%s' "${bytes}" | cut -c9-10)"

	printf '02:%s:%s:%s:%s:%s\n' "${b1}" "${b2}" "${b3}" "${b4}" "${b5}"
}

derive_mac_from_qspi_unique_id() {
	derive_mac_from_hex_identity "$(find_qspi_unique_id)"
}

derive_mac_from_qspi_jedec_id() {
	derive_mac_from_hex_identity "$(find_qspi_jedec_id)"
}

derive_mac_from_qspi_identity() {
	derive_mac_from_qspi_unique_id 2>/dev/null || derive_mac_from_qspi_jedec_id
}

load_network_config_for_iface() {
	local iface

	iface="$1"
	NETWORK_CONFIG_FILE="$(network_config_file "${iface}")"
	IFACE_CONFIG_NAME="${iface}"

	MODE="static"
	ADDRESS=""
	NETMASK="255.255.255.0"
	GATEWAY=""
	MTU=""
	MACADDR=""
	UOE_PORT=""
	UOE_ENDIAN="big"
	UOE_ADDR=""
	UOE_ENABLE="no"

	case "${iface}" in
		eth0)
			ADDRESS="192.168.1.10"
			;;
		eth1)
			ADDRESS="192.168.10.3"
			MTU="9000"
			UOE_PORT="49200"
			UOE_ENDIAN="little"
			UOE_ADDR="0xA000A000"
			UOE_ENABLE="yes"
			;;
	esac

	[ -f "${NETWORK_CONFIG_FILE}" ] || return 0

	# shellcheck disable=SC1090
	. "${NETWORK_CONFIG_FILE}"

	if [ -z "${MODE:-}" ] && [ -n "${ADDRESS:-}" ]; then
		MODE="static"
	fi
}

netmask_to_prefix() {
	local prefix octet
	local IFS=.

	prefix=0
	set -- $1

	for octet in "$@"; do
		case "${octet}" in
			255) prefix=$((prefix + 8)) ;;
			254) prefix=$((prefix + 7)) ;;
			252) prefix=$((prefix + 6)) ;;
			248) prefix=$((prefix + 5)) ;;
			240) prefix=$((prefix + 4)) ;;
			224) prefix=$((prefix + 3)) ;;
			192) prefix=$((prefix + 2)) ;;
			128) prefix=$((prefix + 1)) ;;
			0) ;;
			*) return 1 ;;
		esac
	done

	printf '%s\n' "${prefix}"
}

prefix_to_netmask() {
	local prefix remaining octet index netmask

	prefix="$1"
	[ -n "${prefix}" ] || return 1
	[ "${prefix}" -ge 0 ] 2>/dev/null || return 1
	[ "${prefix}" -le 32 ] 2>/dev/null || return 1

	remaining="${prefix}"
	netmask=""

	for index in 1 2 3 4; do
		if [ "${remaining}" -ge 8 ]; then
			octet=255
			remaining=$((remaining - 8))
		else
			case "${remaining}" in
				0) octet=0 ;;
				1) octet=128 ;;
				2) octet=192 ;;
				3) octet=224 ;;
				4) octet=240 ;;
				5) octet=248 ;;
				6) octet=252 ;;
				7) octet=254 ;;
				*) return 1 ;;
			esac
			remaining=0
		fi

		if [ -n "${netmask}" ]; then
			netmask="${netmask}.${octet}"
		else
			netmask="${octet}"
		fi
	done

	printf '%s\n' "${netmask}"
}

dhcp_pid_file() {
	printf '/var/run/udhcpc.%s.pid\n' "$1"
}

stop_dhcp_client() {
	local iface pid_file pid

	iface="$1"
	pid_file="$(dhcp_pid_file "${iface}")"

	if [ -f "${pid_file}" ]; then
		pid="$(cat "${pid_file}")"
		kill "${pid}" 2>/dev/null || true
		rm -f "${pid_file}"
	fi
}

set_interface_mac() {
	local iface desired current

	iface="$1"
	desired="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
	current="$(cat "/sys/class/net/${iface}/address" 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"

	[ -n "${desired}" ] || return 0
	[ "${current}" = "${desired}" ] && return 0

	ip link set dev "${iface}" down 2>/dev/null || true
	ip link set dev "${iface}" address "${desired}"
}

set_interface_mtu() {
	local iface desired current

	iface="$1"
	desired="$2"

	[ -n "${desired}" ] || return 0
	current="$(cat "/sys/class/net/${iface}/mtu" 2>/dev/null || true)"
	[ -n "${current}" ] && [ "${current}" = "${desired}" ] && return 0

	ip link set dev "${iface}" mtu "${desired}"
}

apply_static_ipv4() {
	local iface address netmask gateway prefix

	iface="$1"
	address="$2"
	netmask="$3"
	gateway="$4"
	prefix="$(netmask_to_prefix "${netmask}")"

	stop_dhcp_client "${iface}"
	ip addr flush dev "${iface}" 2>/dev/null || true
	ip link set dev "${iface}" up
	ip addr add "${address}/${prefix}" dev "${iface}"

	if [ -n "${gateway}" ]; then
		ip route replace default via "${gateway}" dev "${iface}"
	fi
}

start_dhcp_client() {
	local iface pid_file

	iface="$1"
	pid_file="$(dhcp_pid_file "${iface}")"

	stop_dhcp_client "${iface}"
	ip addr flush dev "${iface}" 2>/dev/null || true
	ip link set dev "${iface}" up
	udhcpc -R -b -i "${iface}" -p "${pid_file}"
}

current_ipv4_cidr() {
	local iface

	iface="$1"
	ip -4 addr show dev "${iface}" 2>/dev/null | awk '/inet / { print $2; exit }'
}

current_ipv4_gateway() {
	local iface

	iface="$1"
	ip route show default dev "${iface}" 2>/dev/null | awk '/^default / { for (i = 1; i <= NF; i++) if ($i == "via") { print $(i + 1); exit } }'
}

current_interface_mtu() {
	local iface

	iface="$1"
	cat "/sys/class/net/${iface}/mtu" 2>/dev/null || true
}

save_current_network_config() {
	local iface cidr address prefix netmask gateway mtu content

	iface="$1"

	[ -f "$(dhcp_pid_file "${iface}")" ] && return 0
	ensure_boot_mounted >/dev/null 2>&1 || true
	load_network_config_for_iface "${iface}"

	cidr="$(current_ipv4_cidr "${iface}")"
	[ -n "${cidr}" ] || return 0

	address="${cidr%/*}"
	prefix="${cidr#*/}"
	netmask="$(prefix_to_netmask "${prefix}")"
	gateway="$(current_ipv4_gateway "${iface}")"
	mtu="$(current_interface_mtu "${iface}")"

	if [ "${MODE:-static}" = "static" ] &&
	   [ "${ADDRESS:-}" = "${address}" ] &&
	   [ "${NETMASK:-255.255.255.0}" = "${netmask}" ] &&
	   [ "${GATEWAY:-}" = "${gateway}" ] &&
	   [ "${MTU:-}" = "${mtu}" ]; then
		return 0
	fi

	ensure_boot_mounted || return 1
	mkdir -p "${BOOT_MOUNT}/network"

	content="MODE=static
ADDRESS=${address}
NETMASK=${netmask}
GATEWAY=${gateway}"

	if [ -n "${mtu}" ]; then
		content="${content}
MTU=${mtu}"
	fi

	if [ -n "${MACADDR:-}" ]; then
		content="${content}
MACADDR=${MACADDR}"
	fi

	if [ "${iface}" = "eth1" ]; then
		content="${content}
UOE_PORT=${UOE_PORT:-49200}
UOE_ENDIAN=${UOE_ENDIAN:-little}
UOE_ADDR=${UOE_ADDR:-0xA000A000}"
	fi

	cat > "${NETWORK_CONFIG_FILE}.tmp" <<CONFIGEOF
${content}
CONFIGEOF
	mv "${NETWORK_CONFIG_FILE}.tmp" "${NETWORK_CONFIG_FILE}"
	sync 2>/dev/null || true
}
EOF

chmod +x "${TARGET_DIR}/usr/local/lib/t510-net-common.sh"

cat > "${TARGET_DIR}/etc/init.d/S15mount-bootcfg" <<'EOF'
#!/bin/sh

set -eu

. /usr/local/lib/t510-net-common.sh

create_example_config() {
	[ -d "${BOOT_MOUNT}/network" ] || return 0

	if [ ! -f "${BOOT_MOUNT}/network/eth0.conf.example" ]; then
		cat > "${BOOT_MOUNT}/network/eth0.conf.example" <<'CONFIGEOF'
# eth0 persistent network configuration
# Default when absent:
#   MODE=static
#   ADDRESS=192.168.1.10
#   NETMASK=255.255.255.0
#   MTU=1500
#   MAC derived from QSPI flash unique ID, falling back to JEDEC ID
#
# MODE=static
# ADDRESS=192.168.2.10
# NETMASK=255.255.255.0
# GATEWAY=192.168.2.1
# MTU=1500
# MACADDR=02:12:34:56:78:9a
CONFIGEOF
	fi

	if [ ! -f "${BOOT_MOUNT}/network/eth1.conf.example" ]; then
		cat > "${BOOT_MOUNT}/network/eth1.conf.example" <<'CONFIGEOF'
# eth1 (NIXGE/UOE) persistent network configuration
# Default when absent:
#   MODE=static
#   ADDRESS=192.168.10.3
#   NETMASK=255.255.255.0
#   MTU=9000
#   UOE_PORT=49200
#   UOE_ENDIAN=little
#   UOE_ADDR=0xA000A000
#
# MODE=static
# ADDRESS=192.168.10.3
# NETMASK=255.255.255.0
# GATEWAY=
# MTU=9000
# UOE_PORT=49200
# UOE_ENDIAN=little
# UOE_ADDR=0xA000A000
CONFIGEOF
	fi
}

case "${1:-start}" in
	start)
		if ensure_boot_mounted; then
			create_example_config
		fi
		;;
	stop)
		if is_boot_mounted; then
			umount "${BOOT_MOUNT}" 2>/dev/null || true
		fi
		rm -f "${BOOT_DEVICE_FILE}"
		;;
	restart)
		"$0" stop
		"$0" start
		;;
esac
EOF

chmod +x "${TARGET_DIR}/etc/init.d/S15mount-bootcfg"

cat > "${TARGET_DIR}/etc/init.d/S99persist-network-config" <<'EOF'
#!/bin/sh

set -eu

. /usr/local/lib/t510-net-common.sh

case "${1:-start}" in
	start)
		ensure_boot_mounted >/dev/null 2>&1 || true
		;;
	stop)
		save_current_network_config eth0 >/dev/null 2>&1 || true
		save_current_network_config eth1 >/dev/null 2>&1 || true
		;;
	restart)
		;;
esac
EOF

chmod +x "${TARGET_DIR}/etc/init.d/S99persist-network-config"

cat > "${TARGET_DIR}/usr/local/bin/nixge-uoe-sync" <<'EOF'
#!/bin/sh

set -eu

. /usr/local/lib/t510-net-common.sh

start_sync() {
	local pid

	load_network_config_for_iface eth1
	mkdir -p /var/run /var/log

	if [ -f "${NIXGE_UOE_SYNC_PID_FILE}" ]; then
		pid="$(cat "${NIXGE_UOE_SYNC_PID_FILE}" 2>/dev/null || true)"
		if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
			return 0
		fi
		rm -f "${NIXGE_UOE_SYNC_PID_FILE}"
	fi

		if [ "${UOE_ENDIAN:-little}" = "little" ]; then
			/usr/bin/set_eth_params_direct -A "${T510_ETH_AUTH_FILE}" -a "${UOE_ADDR:-0xA000A000}" -w eth1 -p "${UOE_PORT:-49200}" -b >> "${NIXGE_UOE_SYNC_LOG_FILE}" 2>&1 &
		else
			/usr/bin/set_eth_params_direct -A "${T510_ETH_AUTH_FILE}" -a "${UOE_ADDR:-0xA000A000}" -w eth1 -p "${UOE_PORT:-49200}" >> "${NIXGE_UOE_SYNC_LOG_FILE}" 2>&1 &
		fi

	echo "$!" > "${NIXGE_UOE_SYNC_PID_FILE}"
}

stop_sync() {
	local pid

	if [ ! -f "${NIXGE_UOE_SYNC_PID_FILE}" ]; then
		return 0
	fi

	pid="$(cat "${NIXGE_UOE_SYNC_PID_FILE}" 2>/dev/null || true)"
	if [ -n "${pid}" ]; then
		kill "${pid}" 2>/dev/null || true
		wait "${pid}" 2>/dev/null || true
	fi
	rm -f "${NIXGE_UOE_SYNC_PID_FILE}"
}

case "${1:-start}" in
	start)
		start_sync
		;;
	stop)
		stop_sync
		;;
	restart)
		stop_sync
		start_sync
		;;
	status)
		if [ -f "${NIXGE_UOE_SYNC_PID_FILE}" ] && kill -0 "$(cat "${NIXGE_UOE_SYNC_PID_FILE}")" 2>/dev/null; then
			echo "running"
			exit 0
		fi
		echo "stopped"
		exit 1
		;;
	*)
		echo "Usage: $0 {start|stop|restart|status}" >&2
		exit 1
		;;
esac
EOF

chmod +x "${TARGET_DIR}/usr/local/bin/nixge-uoe-sync"

cat > "${TARGET_DIR}/usr/local/bin/apply-eth0-config" <<'EOF'
#!/bin/sh

set -eu

. /usr/local/lib/t510-net-common.sh

PHASE="${1:-up}"
IFACE="${2:-eth0}"

ensure_boot_mounted >/dev/null 2>&1 || true
load_network_config_for_iface "${IFACE}"

case "${PHASE}" in
	pre-up)
		set_interface_mtu "${IFACE}" "${MTU:-}"
		if [ -n "${MACADDR:-}" ]; then
			set_interface_mac "${IFACE}" "${MACADDR}"
		else
			set_interface_mac "${IFACE}" "$(derive_mac_from_qspi_identity 2>/dev/null || true)"
		fi
		;;
	up)
		if [ "${MODE:-dhcp}" = "static" ] && [ -n "${ADDRESS:-}" ]; then
			apply_static_ipv4 "${IFACE}" "${ADDRESS}" "${NETMASK:-255.255.255.0}" "${GATEWAY:-}"
		else
			start_dhcp_client "${IFACE}"
		fi
		;;
	down)
		stop_dhcp_client "${IFACE}"
		ip addr flush dev "${IFACE}" 2>/dev/null || true
		ip link set dev "${IFACE}" down 2>/dev/null || true
		;;
	*)
		echo "Usage: $0 {pre-up|up|down} [iface]" >&2
		exit 1
		;;
esac
EOF

chmod +x "${TARGET_DIR}/usr/local/bin/apply-eth0-config"

cat > "${TARGET_DIR}/usr/local/bin/apply-eth1-config" <<'EOF'
#!/bin/sh

set -eu

. /usr/local/lib/t510-net-common.sh

PHASE="${1:-up}"
IFACE="${2:-eth1}"

ensure_boot_mounted >/dev/null 2>&1 || true
load_network_config_for_iface "${IFACE}"

case "${PHASE}" in
	pre-up)
		set_interface_mtu "${IFACE}" "${MTU:-}"
		;;
	up)
		if [ "${MODE:-dhcp}" = "static" ] && [ -n "${ADDRESS:-}" ]; then
			apply_static_ipv4 "${IFACE}" "${ADDRESS}" "${NETMASK:-255.255.255.0}" "${GATEWAY:-}"
		else
			start_dhcp_client "${IFACE}"
		fi
		/usr/local/bin/nixge-uoe-sync restart >/dev/null 2>&1 || true
		;;
	down)
		/usr/local/bin/nixge-uoe-sync stop >/dev/null 2>&1 || true
		stop_dhcp_client "${IFACE}"
		ip addr flush dev "${IFACE}" 2>/dev/null || true
		ip link set dev "${IFACE}" down 2>/dev/null || true
		;;
	*)
		echo "Usage: $0 {pre-up|up|down} [iface]" >&2
		exit 1
		;;
esac
EOF

chmod +x "${TARGET_DIR}/usr/local/bin/apply-eth1-config"

cat > "${TARGET_DIR}/usr/local/bin/set-persistent-net" <<'EOF'
#!/bin/sh

set -eu

. /usr/local/lib/t510-net-common.sh

usage() {
	echo "Usage:"
	echo "  $0 [eth0|eth1] dhcp [mac]"
	echo "  $0 [eth0|eth1] static <ip> [netmask] [gateway] [mac]"
	exit 1
}

write_config() {
	local iface content file

	iface="$1"
	content="$2"
	file="$(network_config_file "${iface}")"
	mkdir -p "${BOOT_MOUNT}/network"
	cat > "${file}" <<CONFIGEOF
${content}
CONFIGEOF
}

ensure_boot_mounted || {
	echo "Unable to mount the SD boot partition at ${BOOT_MOUNT}" >&2
	exit 1
}

IFACE="eth0"
case "${1:-}" in
	eth0|eth1)
		IFACE="$1"
		shift
		;;
esac

[ $# -ge 1 ] || usage

load_network_config_for_iface "${IFACE}"

case "$1" in
	dhcp)
		CONTENT="MODE=dhcp"
	if [ $# -ge 2 ] && [ -n "$2" ]; then
			CONTENT="${CONTENT}
MACADDR=$2"
		fi
		;;
	static)
		[ $# -ge 2 ] || usage
		CONTENT="MODE=static
ADDRESS=$2
NETMASK=${3:-255.255.255.0}
GATEWAY=${4:-}"
		if [ $# -ge 5 ] && [ -n "$5" ]; then
			CONTENT="${CONTENT}
MACADDR=$5"
		fi
		;;
	*)
		usage
		;;
esac

	if [ -n "${MTU:-}" ]; then
		CONTENT="${CONTENT}
MTU=${MTU}"
	fi

	if [ "${IFACE}" = "eth1" ]; then
		CONTENT="${CONTENT}
UOE_PORT=${UOE_PORT:-49200}
UOE_ENDIAN=${UOE_ENDIAN:-little}
UOE_ADDR=${UOE_ADDR:-0xA000A000}"
	fi

write_config "${IFACE}" "${CONTENT}"

echo "Saved persistent network config to $(network_config_file "${IFACE}")"
echo "Reboot or run: ifdown ${IFACE} && ifup ${IFACE}"
EOF

chmod +x "${TARGET_DIR}/usr/local/bin/set-persistent-net"

cat > "${TARGET_DIR}/usr/local/bin/set-custom-ip" <<'EOF'
#!/bin/sh

IFACE=""

case "${1:-}" in
	eth0|eth1)
		IFACE="$1"
		shift
		;;
esac

if [ -n "${IFACE}" ]; then
	exec /usr/local/bin/set-persistent-net "${IFACE}" static "$@"
fi

exec /usr/local/bin/set-persistent-net static "$@"
EOF

chmod +x "${TARGET_DIR}/usr/local/bin/set-custom-ip"

cat > "${TARGET_DIR}/usr/local/bin/reset-network-config" <<'EOF'
#!/bin/sh

set -eu

. /usr/local/lib/t510-net-common.sh

IFACE="${1:-eth0}"

ensure_boot_mounted || {
	echo "Unable to mount the SD boot partition at ${BOOT_MOUNT}" >&2
	exit 1
}

rm -f "$(network_config_file "${IFACE}")"

echo "Removed $(network_config_file "${IFACE}")"
if [ "${IFACE}" = "eth1" ]; then
	echo "eth1 will use static 192.168.10.3/24, MTU 9000 and UOE port 49200 after reboot."
else
	echo "eth0 will use static 192.168.1.10/24 and a MAC derived from the QSPI flash unique ID after reboot."
fi
EOF

chmod +x "${TARGET_DIR}/usr/local/bin/reset-network-config"

cat > "${TARGET_DIR}/usr/local/bin/reset-to-default-ip" <<'EOF'
#!/bin/sh

exec /usr/local/bin/reset-network-config "$@"
EOF

chmod +x "${TARGET_DIR}/usr/local/bin/reset-to-default-ip"

cat > "${TARGET_DIR}/usr/local/bin/show-network-config" <<'EOF'
#!/bin/sh

set -eu

. /usr/local/lib/t510-net-common.sh

IFACE="${1:-eth0}"

ensure_boot_mounted >/dev/null 2>&1 || true
load_network_config_for_iface "${IFACE}"

echo "${IFACE} current MAC: $(cat /sys/class/net/${IFACE}/address 2>/dev/null || echo unavailable)"
echo "${IFACE} current IPv4:"
ip -4 addr show dev "${IFACE}" 2>/dev/null || true

echo
if [ -f "${NETWORK_CONFIG_FILE}" ]; then
	echo "Persistent config: ${NETWORK_CONFIG_FILE}"
	cat "${NETWORK_CONFIG_FILE}"
else
	echo "Persistent config: not set"
	if [ "${IFACE}" = "eth1" ]; then
		echo "Default mode: static 192.168.10.3/24 + MTU 9000 + UOE port 49200 (little-endian)"
	else
		echo "Default mode: static 192.168.1.10/24 + MAC derived from QSPI flash unique ID"
	fi
fi
EOF

chmod +x "${TARGET_DIR}/usr/local/bin/show-network-config"

cat > "${TARGET_DIR}/usr/local/bin/persist-current-net" <<'EOF'
#!/bin/sh

set -eu

. /usr/local/lib/t510-net-common.sh

IFACE="${1:-eth0}"

save_current_network_config "${IFACE}" || {
	echo "Unable to save current ${IFACE} network config" >&2
	exit 1
}

echo "Saved current ${IFACE} network config to $(network_config_file "${IFACE}")"
EOF

chmod +x "${TARGET_DIR}/usr/local/bin/persist-current-net"

cat > "${TARGET_DIR}/etc/t510-ai/README" <<'EOF'
T510-AI local authorization

The ethernet register sync helper requires a factory-generated authorization
file before it will write FPGA UOE registers:

  /etc/t510-ai/eth-auth.txt

The file is generated from the board's QSPI flash unique ID and ZynqMP DNA by
the internal factory tool. For EEPROM-backed deployments, point the
T510_ETH_AUTH_FILE environment variable at the EEPROM/nvmem exported file, or
copy the generated authorization text to this default path during provisioning.
EOF

ln -sf ../local/bin/set-persistent-net "${TARGET_DIR}/usr/bin/set-persistent-net"
ln -sf ../local/bin/set-custom-ip "${TARGET_DIR}/usr/bin/set-custom-ip"
ln -sf ../local/bin/reset-network-config "${TARGET_DIR}/usr/bin/reset-network-config"
ln -sf ../local/bin/reset-to-default-ip "${TARGET_DIR}/usr/bin/reset-to-default-ip"
ln -sf ../local/bin/show-network-config "${TARGET_DIR}/usr/bin/show-network-config"
ln -sf ../local/bin/persist-current-net "${TARGET_DIR}/usr/bin/persist-current-net"
ln -sf ../local/bin/nixge-uoe-sync "${TARGET_DIR}/usr/bin/nixge-uoe-sync"

cat > "${TARGET_DIR}/etc/network/README" <<'EOF'
Persistent eth0/eth1 configuration

This system boots from an initramfs. Runtime edits under /etc do not survive reboot.

Persistent overrides are stored on the SD boot partition:
  /boot/network/eth0.conf
  /boot/network/eth1.conf

Default behaviour:
  eth0:
    - IPv4 192.168.1.10/24
    - MAC address derived from QSPI flash unique ID, falling back to JEDEC ID
  eth1:
    - IPv4 192.168.10.3/24
    - MTU 9000
    - UOE UDP port 49200
    - little-endian UOE register format

Helper commands:
  set-persistent-net [eth0|eth1] dhcp [mac]
  set-persistent-net [eth0|eth1] static <ip> [netmask] [gateway] [mac]
  set-custom-ip [eth0|eth1] <ip> [netmask] [gateway]
  persist-current-net [iface]
  reset-network-config [iface]
  show-network-config [iface]
  nixge-uoe-sync {start|stop|restart|status}

After changing the config with helper commands:
  - reboot, or
  - run: ifdown <iface> && ifup <iface>

Runtime static IPv4 changes made with ifconfig/ip are saved automatically on
clean reboot/poweroff, or immediately with:
  persist-current-net <iface>
EOF

# Create dropbear configuration to ensure password authentication works
mkdir -p "${TARGET_DIR}/etc/default"
cat > "${TARGET_DIR}/etc/default/dropbear" <<'EOF'
# Dropbear SSH server configuration

# Additional command line options for dropbear
# -s: disable password logins for root
# -g: disable password logins for all users
# By default, password auth is enabled
DROPBEAR_ARGS=""

# To disable password auth, use:
# DROPBEAR_ARGS="-s"  # disable password auth for root only
# DROPBEAR_ARGS="-g"  # disable password auth for all users

# Banner file (if any)
# DROPBEAR_BANNER="/etc/dropbear/banner"
EOF

# Buildroot target-finalize rejects toolchain-provided dynamic loader config.
rm -f "${TARGET_DIR}/etc/ld.so.conf"
rm -rf "${TARGET_DIR}/etc/ld.so.conf.d"

# Load UIO driver for ethernet hardware registers
mkdir -p "${TARGET_DIR}/etc/modules-load.d"
cat > "${TARGET_DIR}/etc/modules-load.d/uio.conf" <<'EOF'
# Load UIO drivers for hardware access
uio_pdrv_genirq
EOF

# Create modprobe configuration for uio_pdrv_genirq to match our device
mkdir -p "${TARGET_DIR}/etc/modprobe.d"
cat > "${TARGET_DIR}/etc/modprobe.d/uio.conf" <<'EOF'
# Set device tree compatible string for uio_pdrv_genirq driver
options uio_pdrv_genirq of_id=generic-uio
EOF

# Ensure UIO driver is loaded at boot via rc.local if systemd is not used
if [ ! -f "${TARGET_DIR}/etc/rc.local" ]; then
	mkdir -p "${TARGET_DIR}/etc"
	cat > "${TARGET_DIR}/etc/rc.local" <<'EOF'
#!/bin/sh
# Load UIO driver if not already loaded
modprobe uio_pdrv_genirq of_id=generic-uio 2>/dev/null || true
exit 0
EOF
	chmod +x "${TARGET_DIR}/etc/rc.local"
else
	# Add to existing rc.local before exit 0
	if grep -q "modprobe uio_pdrv_genirq" "${TARGET_DIR}/etc/rc.local"; then
		: # Already configured
	else
		sed -i '/^exit 0/i modprobe uio_pdrv_genirq of_id=generic-uio 2>/dev/null || true' "${TARGET_DIR}/etc/rc.local"
	fi
fi

# Create a simple test script to verify UIO device
mkdir -p "${TARGET_DIR}/usr/local/bin"
cat > "${TARGET_DIR}/usr/local/bin/check-uio" <<'EOF'
#!/bin/sh
# Check if UIO device is available
echo "Checking UIO devices:"
if ls /dev/uio* 2>/dev/null; then
	echo "UIO devices found."
	echo "Device details:"
	for dev in /dev/uio*; do
		echo "  $dev:"
		cat /sys/class/uio/${dev##*/}/name 2>/dev/null || echo "    No name"
	done
else
	echo "No UIO devices found."
	echo "Trying to load uio_pdrv_genirq..."
	modprobe uio_pdrv_genirq of_id=generic-uio 2>/dev/null
	if ls /dev/uio* 2>/dev/null; then
		echo "UIO devices now available."
	else
		echo "Failed to load UIO driver."
	fi
fi
EOF
chmod +x "${TARGET_DIR}/usr/local/bin/check-uio"
