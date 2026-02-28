#!/usr/bin/env bash

set -xe

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${CURRENT_DIR}/../.." && pwd)"

# build and install qemu to mkosi locations
"${CURRENT_DIR}/scripts/build-qemu.sh"

# download and install binary packages to mkosi locations
"${CURRENT_DIR}/scripts/bin-packages.sh"

# build and install custom al2023 packages to mkosi locations
"${CURRENT_DIR}/scripts/al2023-package-build.sh"
