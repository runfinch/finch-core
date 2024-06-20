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

    object=$(aws s3 ls "s3://${s3_bucket}" --recursive | grep "${object_pattern}" | sort | tail -n 1 | awk '{print $4}')
    if [[ -z "$object" ]]; then
        echo "error: no match found for pattern ${object_pattern}"
        exit 1
    fi

    echo "$object"
}
