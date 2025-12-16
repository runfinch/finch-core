#!/usr/bin/env bash

source ./util.sh

# TODO: integrate with centralized deps tracking
cosign_version="3.0.2-1"
# This should match cosign_version ideally, but sometimes it doesn't
# see: https://github.com/sigstore/cosign/releases/tag/v2.2.3 release for example
cosign_release="3.0.2"

PKGDIR="${PROJECT_ROOT}/deps/mkosi/mkosi.images/base/mkosi.extra/opt"
rm -rf "${PKGDIR}"
mkdir -p "${PKGDIR}"

curl -L \
  https://github.com/sigstore/cosign/releases/download/v"${cosign_release}"/cosign-"${cosign_version}"."${ARCH}".rpm \
  -o "${PKGDIR}/cosign.rpm"
