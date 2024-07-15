#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# find_latest_object_match_from_s3 is a function for retrieving the
# latest object from a S3 bucket matching the provided pattern.
#
# @param object_pattern - pattern to match S3 objects
# @param s3_bucket - the S3 bucket to inspect
# @return if found, returns the last object matching the pattern with exit code 0
#         else returns an error message with exit code 1.
find_latest_object_match_from_s3() {
    local object_pattern="$1"
    local s3_bucket="$2"

    object=$(aws s3 ls "s3://${s3_bucket}" --recursive | grep -E "${object_pattern}" | sort | tail -n 1 | awk '{print $4}')
    if [[ -z "$object" ]]; then
        echo "error: no match found for pattern ${object_pattern}"
        exit 1
    fi

    echo "$object"
}

# pull_artifact_and_verify_shasum is a function for pulling a Finch core
# artifact and verifying its shasum.
#
# @param artifact_url - URL to artifact
# @param expected_shasum - the expected SHA512SUM for the artifact
pull_artifact_and_verify_shasum() {
    local artifact_url="$1"
    local expected_shasum="$2"

    local artifact
    artifact=$(basename "$artifact_url")

    curl -L --fail "${artifact_url}" > "${artifact}"
    shasum --algorithm 512 "${artifact}" | cut -d ' ' -f 1 | grep -xq "^${expected_shasum}$" || \
      (echo "error: shasum verification failed for \"${artifact}\" dependency" && rm -f "${artifact}" && exit 1)
}
