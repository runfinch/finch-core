#!/usr/bin/env bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Deletes old ECR images for a given architecture, keeping the
# image tagged with latest-<arch> and a specific tag.

set -euxo pipefail

usage() {
  echo "Usage: $0 -r|--repo <ecr-repo-uri> -a|--arch <arch> -t|--keep-tag <keep-tag>"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--repo) repo="$2"; shift 2;;
    -a|--arch) arch="$2"; shift 2;;
    -t|--keep-tag) keep_tag="$2"; shift 2;;
    *) usage;;
  esac
done

[[ -z "${repo:-}" ]] && usage
[[ -z "${arch:-}" ]] && usage
[[ -z "${keep_tag:-}" ]] && usage

repo_name="${repo##*/}"
latest_tag="latest-${arch}"

# Get all image details for this repo
all_images=$(aws ecr describe-images --repository-name "${repo_name}" \
  --output json --no-cli-pager 2>/dev/null || echo '{"imageDetails":[]}')

# Find digests of all images that have $arch somewhere in any tag
arch_digests=$(echo "${all_images}" | \
  jq -r --arg arch "${arch}" '.imageDetails[]
    | select(.imageTags // [] | any(contains($arch)))
    | .imageDigest')

# Find the digest that has the latest-$arch tag (to keep)
keep_digest=$(echo "${all_images}" | \
  jq -r --arg tag "${latest_tag}" '.imageDetails[]
    | select(.imageTags // [] | any(. == $tag))
    | .imageDigest')
echo "Keeping image digest: ${keep_digest}"

# Find the digest for the additional keep tag
keep_tag_digest=$(echo "${all_images}" | \
  jq -r --arg tag "${keep_tag}" '.imageDetails[]
    | select(.imageTags // [] | any(. == $tag))
    | .imageDigest')
echo "Keeping additional image digest: ${keep_tag_digest}"

# Filter out the keep digests
delete_digests=$(echo "${arch_digests}" | \
  grep -v -F "${keep_digest:-NONE}" | \
  grep -v -F "${keep_tag_digest:-NONE}" || true)

if [[ -z "${delete_digests}" ]]; then
  echo "No images to delete."
  exit 0
fi

count=$(echo "${delete_digests}" | wc -l | tr -d ' ')
echo "Found ${count} image(s) to delete:"
echo "${delete_digests}"

image_ids=$(echo "${delete_digests}" | xargs -I{} echo "imageDigest={}" | tr '\n' ' ')
aws ecr batch-delete-image --repository-name "${repo_name}" \
  --image-ids ${image_ids} --no-cli-pager
