#!/usr/bin/env bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# A script to update the rootfs dependency used for Finch on Windows.
#
# Usage: bash update-rootfs.sh -d <S3 bucket>

set -euxo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${CURRENT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/bin/utility.sh"

DEPENDENCY_CLOUDFRONT_URL="https://deps.runfinch.com"
AMD64_FILENAME_PATTERN="finch-rootfs-production-amd64-[0-9]+\.tar\.gz$"
PLATFORM="common"
# ARM not currently supported for Finch on Windows
# AARCH64="aarch64"
X86_64="x86-64"

while getopts d: flag
do
  case "${flag}" in
    d) dependency_bucket=${OPTARG};;
    *) echo "Error: unknown flag" && exit 1;;
  esac
done

[[ -z "$dependency_bucket" ]] && { echo "Error: Dependency bucket not set"; exit 1; }

amd64_deps=$(find_latest_object_match_from_s3 "${AMD64_FILENAME_PATTERN}" "${dependency_bucket}/${PLATFORM}/${X86_64}")
[[ -z "$amd64_deps" ]] && { echo "Error: x86_64 dependency not found"; exit 1; }

amd64_deps_shasum_url="${DEPENDENCY_CLOUDFRONT_URL}/${amd64_deps}.sha512sum"
amd64_deps_shasum=$(curl -L --fail "${amd64_deps_shasum_url}")

# Update rootfs file with latest artifacts and digests
ROOTFS_FILE="${PROJECT_ROOT}/deps/rootfs.conf"
truncate -s 0 "${ROOTFS_FILE}"
{
    echo "ARTIFACT_BASE_URL=${DEPENDENCY_CLOUDFRONT_URL}"
    echo ""
    echo "X86_64_ARTIFACT_PATHING=${PLATFORM}/${X86_64}"
    echo "X86_64_ARTIFACT=$(basename "${amd64_deps}")"
    echo "X86_64_512_DIGEST=${amd64_deps_shasum}"
} >> "${ROOTFS_FILE}"
