#!/usr/bin/env bash

source ./util.sh

pushd "${PROJECT_ROOT}/deps/mkosi/al2023-package-build"
rm -rf ./_output
rm -rf ./artifacts

DOCKER_PACKAGE_BUILD_PARAMS=(buildx build --builder "${BUILDER_NAME}" \
  --platform="linux/$ARCH" -t "al2023-build" --load .
)

if [[ ! -z "${ECR_CACHE_REPO}" ]]; then
  DOCKER_PACKAGE_BUILD_PARAMS+=(--cache-from=type=registry,ref="${ECR_CACHE_REPO}:package-build-${ARCH}")
  DOCKER_PACKAGE_BUILD_PARAMS+=(--cache-to=type=registry,mode=max,image-manifest=true,oci-mediatypes=true,ref="${ECR_CACHE_REPO}:package-build-${ARCH}")
fi
docker "${DOCKER_PACKAGE_BUILD_PARAMS[@]}"

docker save al2023-build > al2023-build.tar
mkdir ./_output
tar -xvf al2023-build.tar -C ./_output

mkdir artifacts

blob_prefix="./_output/blobs/sha256/"
index_manifest=$(jq -r '.manifests[0].digest' ./_output/index.json | sed -e 's/^sha256://')

# Check if the first layer's mediaType is application/vnd.oci.image.layer.v1.tar or .tar+gzip
media_type=$(jq -r '.layers[0].mediaType' "${blob_prefix}${index_manifest}")
if [[ "$media_type" =~ "$application/vnd.oci.image.layer.v1.tar" ]]; then
  # For uncompressed tar layers, use the layer digest directly
  layer_file="${blob_prefix}$(jq -r '.layers[0].digest' "${blob_prefix}${index_manifest}" | sed -e 's/^sha256://' )"
  tar -xvf "${layer_file}" -C artifacts
else
  jq -r '.manifests[] |
    select(.platform.architecture == "amd64" or
           .platform.architecture == "arm64")
  | .digest' "${blob_prefix}${index_manifest}" | while read image_manifest; do
    image_manifest_file="${blob_prefix}$(echo $image_manifest | sed -e 's/^sha256://')"
    layer_file="${blob_prefix}$(jq -r '.layers[0].digest' ${image_manifest_file} | sed -e 's/^sha256://' )"
    tar -xvf "${layer_file}" -C artifacts
    done
fi


find . -iregex "\./artifacts/fuse-sshfs-[0-9].*" -exec cp {} "${PKGDIR}" \;
find . -iregex "\./artifacts/cloud-init-[0-9].*" -exec cp {} "${PKGDIR}" \;
find . -iregex "\./artifacts/fuse-sshfs-[0-9].*${ARCH}.*" -exec cp {} "${PKGDIR}" \;

ls -lah "${CURRENT_DIR}/mkosi.images/base/mkosi.extra/opt/"

popd
