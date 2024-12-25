#!/usr/bin/env bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# A script to update the container runtime full archive used for Finch on macOS and Windows.
#
# Usage: bash update-container-runtime-full-archive.sh -t <Git tag>

set -euxo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${CURRENT_DIR}/.." && pwd)"

while getopts t: flag
do
  case "${flag}" in
    t) tag=${OPTARG};;
    *) echo "Error: unknown flag" && exit 1;;
  esac
done
[[ -z "$tag" ]] && { echo "Error: Git tag not set"; exit 1; }

DEPENDENCY_DOWNLOAD_BASE_URL="https://github.com/containerd/nerdctl/releases/download"
dependency_download_url="${DEPENDENCY_DOWNLOAD_BASE_URL}/${tag}"

# Pull upstream's published release shasums and save for later artifact verification.  
mkdir -p "${PROJECT_ROOT}/downloads"
downloaded_shasums="${PROJECT_ROOT}/downloads/nerdctl-${tag}.sha256sums"
curl -L --fail "${dependency_download_url}/SHA256SUMS" > "${downloaded_shasums}"

version=${tag#v}
aarch64_deps="nerdctl-full-${version}-linux-arm64.tar.gz"
aarch64_deps_shasum=$(grep "${aarch64_deps}" "${downloaded_shasums}" | cut -d ' ' -f 1)
amd64_deps="nerdctl-full-${version}-linux-amd64.tar.gz"
amd64_deps_shasum=$(grep "${amd64_deps}" "${downloaded_shasums}" | cut -d ' ' -f 1)

# Update archive file with latest artifacts and digests.
ARCHIVE_FILE="${PROJECT_ROOT}/deps/container-runtime-full-archive.conf"
truncate -s 0 "${ARCHIVE_FILE}"
{
  echo "ARTIFACT_BASE_URL=${dependency_download_url}"
  echo ""
  echo "AARCH64_ARTIFACT=${aarch64_deps}"
  echo "AARCH64_256_DIGEST=${aarch64_deps_shasum}"
  echo ""
  echo "X86_64_ARTIFACT=${amd64_deps}"
  echo "X86_64_256_DIGEST=${amd64_deps_shasum}"
} >> "${ARCHIVE_FILE}"
