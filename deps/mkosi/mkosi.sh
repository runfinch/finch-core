#!/bin/bash

set -x

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${CURRENT_DIR}/../.." && pwd)"

PROGRAM_NAME="$(basename "$0")"

usage() {
    cat <<EOF
${PROGRAM_NAME} -- a simple wrapper to build multiple types of Finch images.

Usage: ${PROGRAM_NAME}
       ${PROGRAM_NAME} --arch [x86_64|aarch64]
       ${PROGRAM_NAME} -h|--help

Options:

  --arch: Specify the target arch for the image.

  -h,--help: Print this usage message.
EOF
}

error() {
    printf "%s\n" "$*" >/dev/stderr
    exit 1
}

mkosi_args=()

while [ -n "${1-}" ]; do
    case "${1}" in
    -a | --arch)
        arch="${2}"
        shift
        shift
        ;;

    --arch=*)
        arch="${i#*=}"
        shift
        ;;

    -h | --help)
        usage
        exit 0
        ;;

    --)
        shift
        mkosi_args=("$@")
        break
        ;;

    -*)
        error "Unknown option: '$1'."
        ;;
    esac
done

[[ -z "$arch" ]] && { echo "Error: arch not set"; exit 1; }

MKOSI_OUT_DIR="${CURRENT_DIR}/out/${arch}"
mkdir -p "${MKOSI_OUT_DIR}"

mkosi_arch=""
case $arch in
    x86-64)
        mkosi_arch="x86-64"
        ;;
    x86_64)
        mkosi_arch="x86-64"
        ;;
    amd64)
        mkosi_arch="x86-64"
        ;;
    aarch64)
        mkosi_arch="arm64"
        ;;
    arm64)
        mkosi_arch="arm64"
        ;;
    *)
        echo "Unsupported architecture: $arch"
        ;;
esac

# MKOSI_DNF=/usr/bin/dnf4 is needed on distros without this patch https://github.com/rpm-software-management/dnf5/issues/1321
mkosi --debug -C "${CURRENT_DIR}" -f --architecture="${mkosi_arch}" --output-directory="${MKOSI_OUT_DIR}" "${mkosi_args[@]}"
