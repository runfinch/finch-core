#!/usr/bin/env bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# A script to update the lima dependency used for Finch on MacOS and Windows.
#
# Usage: bash update-lima-bundles.sh -d <S3 bucket>

set -euxo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${CURRENT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/bin/utility.sh"

DEPENDENCY_CLOUDFRONT_URL="https://deps.runfinch.com"
AARCH64_FILENAME_PATTERN="lima-and-qemu.macos-aarch64\.[0-9]+\.tar\.gz$"
AMD64_FILENAME_PATTERN="lima-and-qemu.macos-x86_64\.[0-9]+\.tar\.gz$"
AARCH64="aarch64"
X86_64="x86-64"

while getopts d: flag
do
  case "${flag}" in
    d) dependency_bucket=${OPTARG};;
    *) echo "Error: unknown flag" && exit 1;;
  esac
done
[[ -z "$dependency_bucket" ]] && { echo "Error: Dependency bucket not set"; exit 1; }

aarch64_deps=$(find_latest_object_match_from_s3 "${AARCH64_FILENAME_PATTERN}" "${dependency_bucket}/${AARCH64}")
[[ -z "$aarch64_deps" ]] && { echo "Error: aarch64 dependency not found"; exit 1; }

# Need to pull the shasum of the artifact to store for later verification.
aarch64_deps_shasum_url="${DEPENDENCY_CLOUDFRONT_URL}/${aarch64_deps}.sha512sum"
aarch64_deps_shasum=$(curl -L --fail "${aarch64_deps_shasum_url}")
pull_artifact_and_verify_shasum "${DEPENDENCY_CLOUDFRONT_URL}/${aarch64_deps}" "${aarch64_deps_shasum}"

amd64_deps=$(find_latest_object_match_from_s3 "${AMD64_FILENAME_PATTERN}" "${dependency_bucket}/${X86_64}")
[[ -z "$amd64_deps" ]] && { echo "Error: x86_64 dependency not found"; exit 1; }

amd64_deps_shasum_url="${DEPENDENCY_CLOUDFRONT_URL}/${amd64_deps}.sha512sum"
amd64_deps_shasum=$(curl -L --fail "${amd64_deps_shasum_url}")
pull_artifact_and_verify_shasum "${DEPENDENCY_CLOUDFRONT_URL}/${amd64_deps}" "${amd64_deps_shasum}"

# make sure the lima version for both matches
lima_version_aarch64=$(get_lima_version_from_deps "${DEPENDENCY_CLOUDFRONT_URL}/${aarch64_deps}")
lima_version_amd64=$(get_lima_version_from_deps "${DEPENDENCY_CLOUDFRONT_URL}/${amd64_deps}")
if [[ "$lima_version_aarch64" != "$lima_version_amd64" ]]; then
    echo "Error: lima versions do not match b/w two dependency archives: ${lima_version_aarch64} vs ${lima_version_amd64}"
    exit 1
fi

# Update bundles file with latest artifacts and digests.
BUNDLES_FILE="${PROJECT_ROOT}/deps/lima-bundles.conf"
truncate -s 0 "${BUNDLES_FILE}"
{
    echo "ARTIFACT_BASE_URL=${DEPENDENCY_CLOUDFRONT_URL}"
    echo ""
    echo "AARCH64_ARTIFACT_PATHING=${AARCH64}"
    echo "AARCH64_ARTIFACT=$(basename "${aarch64_deps}")"
    echo "AARCH64_512_DIGEST=${aarch64_deps_shasum}"
    echo ""
    echo "X86_64_ARTIFACT_PATHING=${X86_64}"
    echo "X86_64_ARTIFACT=$(basename "${amd64_deps}")"
    echo "X86_64_512_DIGEST=${amd64_deps_shasum}"
    echo ""
    echo "LIMA_VERSION=${lima_version_aarch64}"
} >> "${BUNDLES_FILE}"
