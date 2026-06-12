#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$ROOT_DIR/../.." && pwd)"

PROJECT_NAME="${T510_FNIC_PROJECT_NAME:-t510_fnic_aurora}"
PROJECT_TAG="${T510_FNIC_PROJECT_TAG:-}"
PROJECT_DIR="${T510_FNIC_PROJECT_DIR:-}"
VIVADO_VERSION="${XILINX_VERSION:-2022.2}"
VIVADO_SETTINGS="${VIVADO_SETTINGS:-/opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --tag)
      PROJECT_TAG="$2"
      shift 2
      ;;
    --vivado-version)
      VIVADO_VERSION="$2"
      VIVADO_SETTINGS="/opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: recreate_vivado_project.sh [options]

Options:
  --project-name <name>  Vivado project name
  --project-dir <dir>    Vivado project directory
  --tag <tag>            Optional version tag; defaults project name/dir
  --vivado-version <v>   Vivado version to source
EOF
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$PROJECT_DIR" ]]; then
  if [[ -n "$PROJECT_TAG" ]]; then
    PROJECT_NAME="t510_fnic_${PROJECT_TAG}"
    PROJECT_DIR="${ROOT_DIR}/vivado/project/${PROJECT_NAME}"
  else
    PROJECT_DIR="${ROOT_DIR}/vivado/project/${PROJECT_NAME}"
  fi
fi

if [[ -f "${REPO_ROOT}/scripts/xilinx-settings.sh" ]]; then
  # shellcheck disable=SC1090
  source "${REPO_ROOT}/scripts/xilinx-settings.sh"
else
  if [[ ! -f "$VIVADO_SETTINGS" ]]; then
    printf 'missing Vivado settings: %s\n' "$VIVADO_SETTINGS" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  . "$VIVADO_SETTINGS"
fi

BUILD_STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
GIT_SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || true)"
GIT_STATUS="$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null | head -n 1 >/dev/null && echo dirty || echo clean)"
GIT_SHA="${GIT_SHA:-unknown}"

vivado -mode batch \
  -source "$ROOT_DIR/scripts/vivado/create_t510_fnic_aurora_project.tcl" \
  -tclargs "$PROJECT_NAME" "$PROJECT_DIR" "$PROJECT_TAG" "$BUILD_STAMP" "$GIT_SHA" "$GIT_STATUS"
