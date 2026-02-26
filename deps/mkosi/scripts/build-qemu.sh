#!/usr/bin/env bash

set -xe

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${CURRENT_DIR}/../../.." && pwd)"

source "${CURRENT_DIR}/util.sh"

# Build
pushd "${PROJECT_ROOT}/deps/mkosi/binfmt"
rm -rf ./bin

BUILDER_NAME="qemu-builder"

# create builder if it doesn't exist
if ! docker buildx ls | grep -q "$BUILDER_NAME"; then
    echo "Builder '$BUILDER_NAME' does not exist. Creating it..."
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --use
else
    echo "Builder '$BUILDER_NAME' already exists."
    docker buildx use "$BUILDER_NAME"
fi

# caching helps with rate limiting
DOCKER_PARAMS=(buildx bake desktop \
  --builder "${BUILDER_NAME}"
  --set "*.output=type=local,dest=./bin" \
  --set "*.platform=linux/$docker_arch"
)

DOCKER_CACHE_OPTIONS=""
if [[ ! -z "${ECR_CACHE_REPO}" ]]; then
  DOCKER_PARAMS+=(--set *.cache-from=type=registry,ref="${ECR_CACHE_REPO}:qemu-build-${ARCH}")
  DOCKER_PARAMS+=(--set *.cache-to=type=registry,mode=max,image-manifest=true,oci-mediatypes=true,ref="${ECR_CACHE_REPO}:qemu-build-${ARCH}")
fi
docker "${DOCKER_PARAMS[@]}"

popd

rm -rf "${PROJECT_ROOT}/deps/mkosi/binfmt/bin/linux_amd64/lib/binfmt.d/"
mkdir -p "${PROJECT_ROOT}/deps/mkosi/binfmt/bin/linux_amd64/lib/binfmt.d/"

BUILD_OUT_LIB_DIR="${PROJECT_ROOT}/deps/mkosi/binfmt/bin/linux_${docker_arch}/lib"
mkdir -p "${BUILD_OUT_LIB_DIR}/binfmt.d/"

export HOST_ARCH="${ARCH}"
"${PROJECT_ROOT}/deps/mkosi/scripts/qemu-binfmt-conf.sh" --systemd ALL \
  --credential yes \
  --persistent yes \
  --preserve-argv0 yes \
  -Q /usr/bin \
  --exportdir "${BUILD_OUT_LIB_DIR}/binfmt.d/"

MKOSI_USR_PATH="${PROJECT_ROOT}/deps/mkosi/mkosi.images/base/mkosi.extra/usr"
MKOSI_BINFMT_PATH="${MKOSI_USR_PATH}/lib/binfmt.d"
MKOSI_USR_BIN_PATH="${MKOSI_USR_PATH}/bin"

# this will be of the form ./binfmt/bin/linux_${docker_arch}/usr/bin if building for multiple
# platforms at once, with platform-split=true set
BUILD_OUT_BIN_DIR="${PROJECT_ROOT}/deps/mkosi/binfmt/bin/usr/bin"

# Cleanup
rm -rf "${MKOSI_USR_BIN_PATH}/"
rm -rf "${MKOSI_BINFMT_PATH}/"

# Move files to mkosi.extra dir so they are coppied into the image
mkdir -p "${MKOSI_USR_BIN_PATH}/"

pwd
ls -lah
ls -lah "${PROJECT_ROOT}/deps/mkosi/binfmt/bin"
ls -lah "${PROJECT_ROOT}/deps/mkosi/binfmt/bin/usr"

cp "${BUILD_OUT_BIN_DIR}/qemu-${main_emu_arch}" "${MKOSI_USR_BIN_PATH}/qemu-${main_emu_arch}-static"
cp "${BUILD_OUT_BIN_DIR}/qemu-i386" "${MKOSI_USR_BIN_PATH}/qemu-i386-static"
cp "${BUILD_OUT_BIN_DIR}/qemu-arm" "${MKOSI_USR_BIN_PATH}/qemu-arm-static"

# /lib/ is a symlink to /usr/lib/ in Fedora
mkdir -p "${MKOSI_BINFMT_PATH}"

ls "${BUILD_OUT_LIB_DIR}/"
ls "${BUILD_OUT_LIB_DIR}/binfmt.d/"

# based on the ${ARCH}, some of these files won't be generated so just re-use qemu-${main_emu_arch} every time
cp "${BUILD_OUT_LIB_DIR}/binfmt.d/qemu-${main_emu_arch}.conf" "${MKOSI_BINFMT_PATH}/qemu-${main_emu_arch}-static.conf"
cp "${BUILD_OUT_LIB_DIR}/binfmt.d/qemu-${main_emu_arch}.conf" "${MKOSI_BINFMT_PATH}/qemu-i386-static.conf"
cp "${BUILD_OUT_LIB_DIR}/binfmt.d/qemu-${main_emu_arch}.conf" "${MKOSI_BINFMT_PATH}/qemu-arm-static.conf"

sed -i "s|/usr/bin/qemu-${main_emu_arch}|/usr/bin/qemu-${main_emu_arch}-static|g" "${MKOSI_BINFMT_PATH}/qemu-${main_emu_arch}-static.conf"
sed -i "s|/usr/bin/qemu-${main_emu_arch}|/usr/bin/qemu-i386-static|g" "${MKOSI_BINFMT_PATH}/qemu-i386-static.conf"
sed -i "s|/usr/bin/qemu-${main_emu_arch}|/usr/bin/qemu-arm-static|g" "${MKOSI_BINFMT_PATH}/qemu-arm-static.conf"
