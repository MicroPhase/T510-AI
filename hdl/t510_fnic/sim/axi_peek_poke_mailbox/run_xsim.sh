#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VIVADO_VERSION="${XILINX_VERSION:-2022.2}"
VIVADO_SETTINGS="${VIVADO_SETTINGS:-/opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh}"
SIM_DIR="${SCRIPT_DIR}/xsim_work"
SNAPSHOT="tb_axi_peek_poke_mailbox"

if [[ ! -f "${VIVADO_SETTINGS}" ]]; then
  printf 'missing Vivado settings: %s\n' "${VIVADO_SETTINGS}" >&2
  exit 1
fi

source "${VIVADO_SETTINGS}"

rm -rf "${SIM_DIR}"
mkdir -p "${SIM_DIR}"
cd "${SIM_DIR}"

xvlog -sv -work work \
  "${ROOT_DIR}/top/t510_fnic/rtl/axi_peek_poke_v1_0_S00_AXI.v" \
  "${SCRIPT_DIR}/tb_axi_peek_poke_mailbox.sv"

xelab -debug typical -top "${SNAPSHOT}" -snapshot "${SNAPSHOT}"
xsim "${SNAPSHOT}" -runall
