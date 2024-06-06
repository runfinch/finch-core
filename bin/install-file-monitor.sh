#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# A script for installing file monitor dependency.
#
# Usage: bash install-file-monitor.sh

set -euxo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${CURRENT_DIR}/.." && pwd)"

DEPENDENCY="FileMonitor_1.3.0.zip"
DEPENDENCY_URL="https://bitbucket.org/objective-see/deploy/downloads/FileMonitor_1.3.0.zip"
DEPENDENCY_DIGEST="17a1335e76fb9298ed4e33fd7d7fc8e2f96c1b849db86fb250caf58f1689d2b2bf09eb5cc8cd10ac95f9b8bf38c90b8b99899505b3f3816cdfd14038011c000e"

# Pull tarball to project's downloads directory to verify and install.
mkdir -p "${PROJECT_ROOT}/downloads"
file="${PROJECT_ROOT}/downloads/${DEPENDENCY}"
curl -L --fail ${DEPENDENCY_URL} > "${file}"

# Validate shasum for downloaded dependency
(shasum --algorithm 512 "${file}" | cut -d ' ' -f 1 | grep -xq "^${DEPENDENCY_DIGEST}$") || \
  (echo "error: shasum verification failed for file monitor dependency" && exit 1)

rm -rf /Applications/FileMonitor.app
unzip "${file}" -d /Applications
