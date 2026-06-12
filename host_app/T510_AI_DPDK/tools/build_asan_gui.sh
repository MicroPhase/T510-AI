#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build_asan"

if [[ -f "${BUILD_DIR}/CMakeCache.txt" ]]; then
  CMAKE_HOME_DIR="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "${BUILD_DIR}/CMakeCache.txt" | head -n1)"
  if [[ -n "${CMAKE_HOME_DIR}" && "${CMAKE_HOME_DIR}" != "${ROOT_DIR}" ]]; then
    echo "Removing stale CMake cache from: ${BUILD_DIR}"
    rm -rf "${BUILD_DIR}"
  fi
fi

cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DT510_AI_ENABLE_ASAN=ON \
  -DT510_AI_ENABLE_UBSAN=ON

cmake --build "${BUILD_DIR}" --target t510_ai_gui -j

echo "ASan/UBSan GUI build ready:"
echo "  ${BUILD_DIR}/t510_ai_gui"
