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

# Read actual dependency versions from the archive
curr_arch=$(uname -m)
if [[ "${curr_arch}" == "arm64" ]]; then
  dependency_file="${aarch64_deps}"
else
  dependency_file="${amd64_deps}"
fi
curl -Lo "${PROJECT_ROOT}/downloads/${dependency_file}" "${dependency_download_url}/${dependency_file}"
mkdir -p "${PROJECT_ROOT}/downloads/temp"
tar -C "${PROJECT_ROOT}/downloads/temp" -xzf "${PROJECT_ROOT}/downloads/${dependency_file}"

# nerdctl writes all the included components versions in this file
nerdctl_full_readme="${PROJECT_ROOT}/downloads/temp/share/doc/nerdctl-full/README.md"
nerdctl_version=$(grep "^- nerdctl:" "${nerdctl_full_readme}" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
containerd_version=$(grep "^- containerd:" "${nerdctl_full_readme}" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
runc_version=$(grep "^- runc:" "${nerdctl_full_readme}" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
cni_plugins_version=$(grep "^- CNI plugins:" "${nerdctl_full_readme}" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
buildkit_version=$(grep "^- BuildKit:" "${nerdctl_full_readme}" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
rm -r "${PROJECT_ROOT}/downloads/temp" "${PROJECT_ROOT}/downloads/${dependency_file}"

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
  echo ""
  echo "# These versions were read from the nerdctl-full archive above."
  echo "# PLEASE DO NOT UPDATE THESE MANUALLY"
  echo "NERDCTL_VERSION=\"${nerdctl_version}\""
  echo "CONTAINERD_VERSION=\"${containerd_version}\""
  echo "BUILDKIT_VERSION=\"${buildkit_version}\""
  echo "RUNC_VERSION=\"${runc_version}\""
  echo "CNI_PLUGINS_VERSION=\"${cni_plugins_version}\""
} >> "${ARCHIVE_FILE}"
