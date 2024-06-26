#!/usr/bin/env bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# A script for pulling and unpacking a dependency artifact.
#
# Usage: bash install.sh [-o|--output <FILEPATH>] <SOURCES_FILE>

set -euxo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${CURRENT_DIR}/.." && pwd)"

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

artifact=""
digest=""
url="${ARTIFACT_BASE_URL}"

arch="$(uname -m)"
case "${arch}" in
  "arm64")
    if [[ -z "$AARCH64_ARTIFACT" ]]; then
      echo "error: ARM architecture not supported for dependency" && exit 1
    fi

    artifact="${AARCH64_ARTIFACT}"
    digest="${AARCH64_512_DIGEST}"

    if [[ -n "${AARCH64_ARTIFACT_PATHING+unset}" ]]; then
      url="${url}/${AARCH64_ARTIFACT_PATHING}"
    fi
    ;;
  "x86_64")
    artifact="${X86_64_ARTIFACT}"
    digest="${X86_64_512_DIGEST}"

    if [[ -n "${X86_64_ARTIFACT_PATHING+unset}" ]]; then
      url="${url}/${X86_64_ARTIFACT_PATHING}"
    fi
    ;;
  *)
    echo "error: unsupported architecture" && exit 1
    ;;
esac

windows=false
os="$(uname -s)"
case "${os}" in
  "Darwin")
    ;;
  CYGWIN*|MINGW32*|MINGW*|MSYS*)
    windows=true
    ;;
  *)
    echo "error: unsupported operating system" && exit 1
    ;;
esac

# pull artifact from dependency repository
curl -L --fail "${url}/${artifact}" > "${file}"

# validate artifact digest
if [[ $windows = true ]]; then
  (pwsh "${PROJECT_ROOT}/bin/verify_hash.ps1" "${file}" "${digest}") || \
    (echo "error: shasum verification failed for dependency" && rm -f "${file}" && exit 1)
else
  (shasum --algorithm 512 "${file}" | cut -d ' ' -f 1 | grep -xq "^${digest}$") || \
    (echo "error: shasum verification failed for dependency" && rm -f "${file}" && exit 1)
fi
