#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
UBUNTU_DEPS="$ROOT_DIR/deps/ubuntu-deps.conf"
AL_DEPS="$ROOT_DIR/deps/amazon-linux-deps.conf"

# Function to get latest tag from GitHub API
get_latest_tag() {
    local repo="$1"
    curl -s "https://api.github.com/repos/$repo/releases/latest" | \
    grep '"tag_name":' | \
    head -1 | \
    cut -d'"' -f4 | \
    sed 's/^v//'
}

# Function to get commit hash for a tag
get_commit_for_tag() {
    local repo="$1"
    local tag="$2"
    [[ $tag != v* ]] && tag="v$tag"
    curl -s "https://api.github.com/repos/$repo/commits/$tag" | \
    grep '"sha":' | \
    head -1 | \
    cut -d'"' -f4
}

# Function to get nerdctl dockerfile content
get_nerdctl_dockerfile() {
    local nerdctl_tag="$1"
    [[ $nerdctl_tag != v* ]] && nerdctl_tag="v$nerdctl_tag"

    local dockerfile_url="https://raw.githubusercontent.com/containerd/nerdctl/$nerdctl_tag/Dockerfile"
    local dockerfile_content=$(curl -s "$dockerfile_url")

    echo "$dockerfile_content"
}

# Function to get BuildKit version from nerdctl Dockerfile
get_buildkit_version() {
    local dockerfile_content="$1"

    local buildkit_version=$(echo "$dockerfile_content" | grep -E '^ARG BUILDKIT_VERSION=' | cut -d'=' -f2 | sed 's/@BINARY$//' | sed 's/^v//')
    
    echo "$buildkit_version"
}

# Function to get cni plugin version from nerdctl Dockerfile
get_cni_plugin_version() {
    local dockerfile_content="$1"
    
    local cni_plugin_version=$(echo "$dockerfile_content" | grep -E '^ARG CNI_PLUGINS_VERSION=' | cut -d'=' -f2 | sed 's/@BINARY$//' | sed 's/^v//')
    
    echo "$cni_plugin_version"
}

# Function to get Cosign version from nerdctl Dockerfile
get_cosign_version() {
    local dockerfile_content="$1"
    
    # Extract Cosign version from COPY instruction
    # Current Format: COPY --from=ghcr.io/sigstore/cosign/cosign:v2.2.3@sha256:... /ko-app/cosign /usr/local/bin/cosign
    local cosign_version=$(echo "$dockerfile_content" | grep -E 'COPY --from=ghcr.io/sigstore/cosign/cosign:' | sed -E 's/.*cosign:v([0-9]+\.[0-9]+\.[0-9]+).*/\1/' | head -1)
    
    echo "$cosign_version"
}

# Function to update a dependency file
update_dependency() {
    local name="$1"
    local new_release="$2"
    local new_commit="$3"
    local deps_file="$4"
    local temp_file=$(mktemp)
    
    sed \
        -e "s/${name}_RELEASE=\"[^\"]*\"/${name}_RELEASE=\"$new_release\"/" \
        -e "s/${name}_COMMIT=\"[^\"]*\"/${name}_COMMIT=\"$new_commit\"/" \
        "$deps_file" > "$temp_file"
    
    # Use deps file permissions
    chmod --reference="$deps_file" "$temp_file"
    mv "$temp_file" "$deps_file"
}

# Function to update dependency in ubuntu-deps.conf file
update_ubuntu_dependency() {
    update_dependency "$1" "$2" "$3" "$UBUNTU_DEPS"
}

# Function to update dependency in amazon-linux-deps.conf file
update_al_dependency() {
    update_dependency "$1" "$2" "$3" "$AL_DEPS"
}

# The following package versions are updated in amazon-linux-deps.conf file -
#   - finch-daemon
#   - buildkit
#   - soci
#   - cosign
# And the following are updated in ubuntu-deps.conf file -
#   - finch-daemon
#   - nerdctl
#   - buildkit
#   - soci
#   - cni plugins
#   - cosign
echo "Updating dependencies..."

# Update finch-daemon
echo "Updating finch-daemon..."
FINCHD_LATEST=$(get_latest_tag "runfinch/finch-daemon")
FINCHD_COMMIT=$(get_commit_for_tag "runfinch/finch-daemon" "$FINCHD_LATEST")
update_ubuntu_dependency "FINCHD" "$FINCHD_LATEST" "$FINCHD_COMMIT"
update_al_dependency "FINCHD" "$FINCHD_LATEST" "$FINCHD_COMMIT"

# Update nerdctl
echo "Updating nerdctl..."
NERDCTL_LATEST=$(get_latest_tag "containerd/nerdctl")
NERDCTL_COMMIT=$(get_commit_for_tag "containerd/nerdctl" "$NERDCTL_LATEST")
update_ubuntu_dependency "NERDCTL" "$NERDCTL_LATEST" "$NERDCTL_COMMIT"

# Get nerdctl dockerfile content
echo "Getting nerdctl dockerfile content..."
NERDCTL_DOCKERFILE=$(get_nerdctl_dockerfile "$NERDCTL_LATEST")

# Get BuildKit version from nerdctl Dockerfile
echo "Getting BuildKit version from nerdctl Dockerfile..."
BUILDKIT_VERSION=$(get_buildkit_version "$NERDCTL_DOCKERFILE")

# Update buildkit with version from nerdctl
echo "Updating buildkit to version $BUILDKIT_VERSION..."
BUILDKIT_COMMIT=$(get_commit_for_tag "moby/buildkit" "$BUILDKIT_VERSION")
update_ubuntu_dependency "BUILDKIT" "$BUILDKIT_VERSION" "$BUILDKIT_COMMIT"
update_al_dependency "BUILDKIT" "$BUILDKIT_VERSION" "$BUILDKIT_COMMIT"

# Update soci-snapshotter
echo "Updating soci-snapshotter..."
SOCI_LATEST=$(get_latest_tag "awslabs/soci-snapshotter")
SOCI_COMMIT=$(get_commit_for_tag "awslabs/soci-snapshotter" "$SOCI_LATEST")
update_ubuntu_dependency "SOCI" "$SOCI_LATEST" "$SOCI_COMMIT"
update_al_dependency "SOCI" "$SOCI_LATEST" "$SOCI_COMMIT"

# Update CNI plugins
echo "Updating CNI plugins..."
CNI_LATEST=$(get_cni_plugin_version "$NERDCTL_DOCKERFILE")
CNI_COMMIT=$(get_commit_for_tag "containernetworking/plugins" "$CNI_LATEST")
update_ubuntu_dependency "CNI" "$CNI_LATEST" "$CNI_COMMIT"

# Get Cosign version from nerdctl Dockerfile
echo "Getting Cosign version from nerdctl Dockerfile..."
COSIGN_VERSION=$(get_cosign_version "$NERDCTL_DOCKERFILE")

# Update cosign with version from nerdctl
echo "Updating cosign to version $COSIGN_VERSION..."
if [ -n "$COSIGN_VERSION" ]; then
    COSIGN_COMMIT=$(get_commit_for_tag "sigstore/cosign" "$COSIGN_VERSION")
    update_ubuntu_dependency "COSIGN" "$COSIGN_VERSION" "$COSIGN_COMMIT"
    update_al_dependency "COSIGN" "$COSIGN_VERSION" "$COSIGN_COMMIT"
else
    echo "WARNING: Failed to extract cosign version from nerdctl Dockerfile"
fi

echo "Dependencies updated successfully!"
echo "Updated versions:"
echo "  finch-daemon: $FINCHD_LATEST"
echo "  nerdctl: $NERDCTL_LATEST"
echo "  buildkit: $BUILDKIT_VERSION"
echo "  soci-snapshotter: $SOCI_LATEST"
echo "  CNI plugins: $CNI_LATEST"
echo "  cosign: $COSIGN_VERSION"
