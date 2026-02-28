#!/usr/bin/env bash

set -xe

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${CURRENT_DIR}/../../.." && pwd)"

# set arch to uname if its not set
uname=$(uname -m)
ARCH="${ARCH:-$uname}"

# https://github.com/systemd/mkosi/blob/c29462cfefe9b9b366a007d9f06edc4d5c65e315/mkosi/resources/man/mkosi.1.md?plain=1#L449
mkosi_arch=""
docker_arch=""
main_emu_arch=""
case $ARCH in
    x86_64)
        docker_arch="amd64"
        mkosi_arch="x86-64"
        main_emu_arch="aarch64"
        ;;
    aarch64)
        docker_arch="arm64"
        mkosi_arch="arm64"
        main_emu_arch="x86_64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        ;;
esac
