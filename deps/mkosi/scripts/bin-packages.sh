#!/usr/bin/env bash

set -xe

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${CURRENT_DIR}/../../.." && pwd)"

source "${CURRENT_DIR}/util.sh"

# Source centralized deps config for cosign version
source "${PROJECT_ROOT}/deps/full-os.conf"

PKGDIR="${PROJECT_ROOT}/deps/mkosi/mkosi.images/base/mkosi.extra/opt/bin"
rm -rf "${PKGDIR}"
mkdir -p "${PKGDIR}"

curl -L \
  https://github.com/sigstore/cosign/releases/download/v"${COSIGN_RELEASE}"/cosign-"${COSIGN_VERSION}"."${ARCH}".rpm \
  -o "${PKGDIR}/cosign.rpm"

# Verify SHA256 digest if provided
if [ "${ARCH}" = "aarch64" ]; then
    expected_sha="${COSIGN_AARCH64_RPM_SHA256_DIGEST}"
elif [ "${ARCH}" = "x86_64" ]; then
    expected_sha="${COSIGN_X86_64_RPM_SHA256_DIGEST}"
else
    echo "Error: Unknown architecture ${ARCH}"
    exit 1
fi

if [ -n "$expected_sha" ]; then
    actual_sha=$(sha256sum "${PKGDIR}/cosign.rpm" | cut -d ' ' -f 1)
    if [ "$actual_sha" != "$expected_sha" ]; then
        echo "Error: SHA256 mismatch for cosign.rpm"
        echo "Expected: $expected_sha"
        echo "Actual:   $actual_sha"
        exit 1
    fi
    echo "SHA256 verification passed for cosign.rpm"
fi
