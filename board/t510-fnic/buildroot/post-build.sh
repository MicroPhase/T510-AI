#!/bin/sh
set -eu

TARGET_DIR="$1"

mkdir -p "${TARGET_DIR}/etc" "${TARGET_DIR}/etc/network" "${TARGET_DIR}/etc/init.d"

sed -i \
	-e 's|^ttyPS[01]::respawn:.*$|ttyPS0::respawn:/sbin/getty -L ttyPS0 115200 vt100|' \
	"${TARGET_DIR}/etc/inittab"

if ! grep -q '^ttyPS0::respawn:' "${TARGET_DIR}/etc/inittab"; then
	printf 'ttyPS0::respawn:/sbin/getty -L ttyPS0 115200 vt100\n' >> "${TARGET_DIR}/etc/inittab"
fi

cat > "${TARGET_DIR}/etc/network/interfaces" <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
	address 192.168.1.10
	netmask 255.255.255.0
EOF

if [ -f "${TARGET_DIR}/etc/shadow" ]; then
	if command -v openssl >/dev/null 2>&1; then
		SALT="$(openssl rand -base64 12 2>/dev/null | tr -d '\n' | cut -c1-16)"
		PASS_HASH="$(openssl passwd -6 -salt "$SALT" microphase 2>/dev/null || true)"
	else
		PASS_HASH=""
	fi

	if [ -z "$PASS_HASH" ]; then
		PASS_HASH='$6$Wv6yKd7R$X.9w8QbL7p6Fc3tY2hJq1M.nV4Bz5rAeCxGdHfIjKlNmOoPsRtSuVwXyZ'
	fi

	if grep -q '^root:' "${TARGET_DIR}/etc/shadow"; then
		sed -i "s|^root:[^:]*:|root:${PASS_HASH}:|" "${TARGET_DIR}/etc/shadow"
	else
		printf 'root:%s:0:0:99999:7:::\n' "$PASS_HASH" >> "${TARGET_DIR}/etc/shadow"
	fi
fi

cat > "${TARGET_DIR}/etc/issue" <<'EOF'
T510 FNIC Buildroot Linux
EOF

cat > "${TARGET_DIR}/etc/motd" <<'EOF'
T510 FNIC RFSoC image

RFDC control:
  t510-fnic-rfdc
  t510-fnic-rfdc --type adc --tile 0 --block 0 --freq 1850
EOF
