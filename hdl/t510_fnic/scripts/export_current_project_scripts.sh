#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$ROOT_DIR/../.." && pwd)"

APPLY=0
PROJECT_FILE="${ROOT_DIR}/vivado/project/t510_fnic_aurora/t510_fnic_aurora.xpr"
OUT_DIR="${ROOT_DIR}/scripts/vivado/generated"
IP_DIR="${ROOT_DIR}/lib/ip"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --project)
      PROJECT_FILE="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --ip-dir)
      IP_DIR="$2"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: scripts/export_current_project_scripts.sh [options]

Options:
  --project <xpr>   Vivado project to export from
  --out-dir <dir>   Directory for generated Tcl output
  --ip-dir <dir>    Directory to copy non-BD project IP .xci/.xcix files into
  --apply           Replace create_t510_fnic_aurora_bd.tcl and
                    create_t510_fnic_aurora_sources.tcl with Tcl exported
                    from the current Vivado project
EOF
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$PROJECT_FILE" ]]; then
  NESTED_PROJECT_FILE="${ROOT_DIR}/vivado/project/t510_fnic_aurora/vivado/project/t510_fnic_aurora/t510_fnic_aurora.xpr"
  if [[ -f "$NESTED_PROJECT_FILE" ]]; then
    PROJECT_FILE="$NESTED_PROJECT_FILE"
  fi
fi

if [[ -f "${REPO_ROOT}/scripts/xilinx-settings.sh" ]]; then
  # shellcheck disable=SC1090
  source "${REPO_ROOT}/scripts/xilinx-settings.sh"
else
  VIVADO_VERSION="${XILINX_VERSION:-2022.2}"
  VIVADO_SETTINGS_FILE="${VIVADO_SETTINGS_FILE:-/opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh}"
  VITIS_SETTINGS_FILE="${VITIS_SETTINGS_FILE:-/opt/Xilinx/Vitis/${VIVADO_VERSION}/settings64.sh}"

  if [[ ! -f "${VIVADO_SETTINGS_FILE}" ]]; then
    echo "missing Vivado settings file: ${VIVADO_SETTINGS_FILE}" >&2
    exit 1
  fi
  if [[ -f "${VITIS_SETTINGS_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${VITIS_SETTINGS_FILE}"
  fi
  # shellcheck disable=SC1090
  source "${VIVADO_SETTINGS_FILE}"
fi

vivado -mode batch \
  -source "${ROOT_DIR}/scripts/vivado/export_current_project_scripts.tcl" \
  -tclargs "${PROJECT_FILE}" "${OUT_DIR}" "${APPLY}" "${ROOT_DIR}" "${IP_DIR}"
