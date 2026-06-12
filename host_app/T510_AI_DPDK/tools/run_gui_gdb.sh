#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${1:-${ROOT_DIR}/build/t510_ai_gui}"
LOG_DIR="${ROOT_DIR}/debug_logs"
mkdir -p "${LOG_DIR}"
STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/gdb_gui_${STAMP}.log"

ulimit -c unlimited || true

echo "Running under gdb, log -> ${LOG_FILE}"

gdb -q \
  -ex "set pagination off" \
  -ex "set logging file ${LOG_FILE}" \
  -ex "set logging overwrite on" \
  -ex "set logging enabled on" \
  -ex "handle SIGPIPE nostop noprint pass" \
  -ex "run" \
  -ex "thread apply all bt full" \
  -ex "quit" \
  --args "${BIN}"

echo "GDB log saved to:"
echo "  ${LOG_FILE}"
