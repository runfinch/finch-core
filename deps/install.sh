#!/usr/bin/env bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# A script for pulling and unpacking a dependency artifact.
#
# Usage: bash install.sh [-o|--output <FILEPATH>] <SOURCES_FILE>

set -euxo pipefail

file=""
sources=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --output|-o)
      shift # past argument
      file=$1
      shift # past value
      ;;
    --*|-*)
      echo "error: unknown option $1"
      exit 1
      ;;
    *)
      sources=$1
      shift # past value
      ;;
  esac
done

if [[ -z "$sources" ]]; then
  echo "error: sources file not provided" && exit 1
fi

# shellcheck source=/dev/null
source "${sources}"

DEPENDENCY_BASE_URL="https://deps.runfinch.com"
AARCH64="aarch64"
X86_64="x86-64"

artifact=""
digest=""

arch="$(uname -m)"
case "${arch}" in
  "arm64")
    artifact="${AARCH64}/${AARCH64_ARTIFACT}"
    digest=${AARCH64_512_DIGEST}
    ;;
  "x86_64")
    artifact="${X86_64}/${X86_64_ARTIFACT}"
    digest=${X86_64_512_DIGEST}
    ;;
  *)
    echo "error: unsupported architecture" && exit 1
    ;;
esac

# pull artifact from dependency repository
url="${DEPENDENCY_BASE_URL}/${artifact}"
curl -L --fail "${url}" > "${file}"

# validate shasum for downloaded artifact
(shasum --algorithm 512 "${file}" | cut -d ' ' -f 1 | grep -xq "^${digest}$") || \
  (echo "error: shasum verification failed for lima dependency" && exit 1)
