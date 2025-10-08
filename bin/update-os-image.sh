#!/usr/bin/env bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# A script to update the base os image used for Finch on macOS.
#
# Usage: bash update-os-image.sh -d <S3 bucket>

set -euxo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${CURRENT_DIR}/.." && pwd)"

# shellcheck source=/dev/null
source "${PROJECT_ROOT}/bin/utility.sh"

DEPENDENCY_CLOUDFRONT_URL="https://deps.runfinch.com"
AARCH64_FILENAME_PATTERN="Fedora-Cloud-Base-.*\.aarch64-[0-9]+\.qcow2$"
AMD64_FILENAME_PATTERN="Fedora-Cloud-Base-.*\.x86_64-[0-9]+\.qcow2$"

while getopts d: flag
do
  case "${flag}" in
    d) dependency_bucket=${OPTARG};;
    *) echo "Error: unknown flag" && exit 1;;
  esac
done

[[ -z "$dependency_bucket" ]] && { echo "Error: dependency bucket not set"; exit 1; }

aarch64_deps=$(find_latest_object_match_from_s3 "${AARCH64_FILENAME_PATTERN}" "${dependency_bucket}")
[[ -z "$aarch64_deps" ]] && { echo "Error: aarch64 dependency not found"; exit 1; }

# Need to pull the shasum of the artifact to store for later verification.
aarch64_deps_shasum_url="${DEPENDENCY_CLOUDFRONT_URL}/${aarch64_deps}.sha512sum"
aarch64_deps_shasum=$(curl -L --fail "${aarch64_deps_shasum_url}")

pull_artifact_and_verify_shasum "${DEPENDENCY_CLOUDFRONT_URL}/${aarch64_deps}" "${aarch64_deps_shasum}"

amd64_deps=$(find_latest_object_match_from_s3 "${AMD64_FILENAME_PATTERN}" "${dependency_bucket}")
[[ -z "$amd64_deps" ]] && { echo "Error: x86_64 dependency not found"; exit 1; }

amd64_deps_shasum_url="${DEPENDENCY_CLOUDFRONT_URL}/${amd64_deps}.sha512sum"
amd64_deps_shasum=$(curl -L --fail "${amd64_deps_shasum_url}")

pull_artifact_and_verify_shasum "${DEPENDENCY_CLOUDFRONT_URL}/${amd64_deps}" "${amd64_deps_shasum}"

# Update base os file with latest artifacts and digests
OS_FILE="${PROJECT_ROOT}/deps/full-os.conf"
truncate -s 0 "${OS_FILE}"
{
    echo "ARTIFACT_BASE_URL=${DEPENDENCY_CLOUDFRONT_URL}"
    echo ""
    echo "# From https://dl.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/aarch64/images/"
    echo "AARCH64_ARTIFACT=$(basename "${aarch64_deps}")"
    echo "AARCH64_512_DIGEST=${aarch64_deps_shasum}"
    echo ""
    echo "# From https://dl.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/"
    echo "X86_64_ARTIFACT=$(basename "${amd64_deps}")"
    echo "X86_64_512_DIGEST=${amd64_deps_shasum}"
} >> "${OS_FILE}"
