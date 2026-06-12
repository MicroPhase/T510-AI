#!/bin/bash
set -euo pipefail

VIVADO_VERSION="${XILINX_VERSION:-2022.2}"
VIVADO_SETTINGS_FILE="${VIVADO_SETTINGS_FILE:-/opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh}"
VITIS_SETTINGS_FILE="${VITIS_SETTINGS_FILE:-/opt/Xilinx/Vitis/${VIVADO_VERSION}/settings64.sh}"

if [ ! -f "${VIVADO_SETTINGS_FILE}" ]; then
	echo "missing Vivado settings file: ${VIVADO_SETTINGS_FILE}" >&2
	exit 1
fi

if [ ! -f "${VITIS_SETTINGS_FILE}" ]; then
	echo "missing Vitis settings file: ${VITIS_SETTINGS_FILE}" >&2
	exit 1
fi

source "${VIVADO_SETTINGS_FILE}"
source "${VITIS_SETTINGS_FILE}"
