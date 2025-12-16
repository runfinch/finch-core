#!/usr/bin/env bash

set -xe

# build and install qemu to mkosi locations
exec ./scripts/build-qemu.sh

# download and install binary packages to mkosi locations
exec ./scripts/build-qemu.sh

# build and install custom al2023 packages to mkosi locations
exec ./scripts/al2023-package-build.sh
