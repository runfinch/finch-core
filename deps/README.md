# Required Dependencies

## Installation

All required dependencies for the Finch virtual machine are
available via https://www.deps.runfinch.com.

Finch core provides a utility tool ([`deps/install.sh`](../deps/install.sh)) for pulling and verifying the required artifacts for each platform.

### Artifact configuration

To effectively pull and verify dependency artifacts, the tooling
needs several pieces of information. This artifact metadata is
modeled in artifact configuration files. e.g. [`deps/lima-bundles.conf`](../deps/lima-bundles.conf)
models the information required to pull and verify the Lima bundle
needed for running Finch on macOS.

* **ARTIFACT_BASE_URL** - the consistent part or the root of the
URL for pulling the artifact. (Required)
* **AARCH64_ARTIFACT_PATHING** - the specific pathing for the ARM
variant of the artifact. (Optional)
* **AARCH64_ARTIFACT** - the ARM64 artifact file name.
* **AARCH64_512_DIGEST** - the SHA-512 checksum for the artifact.
* **X86_64_ARTIFACT_PATHING** - the specific pathing for the
x86-64 variant of the artifact. (Optional)
* **X86_64_ARTIFACT** - the x86-64 artifact file name.
* **X86_64_512_DIGEST** - the SHA-512 checksum for the artifact.

** Note: not every dependency will require both ARM and x86-64 
architecture support. e.g. Finch on Windows ARM is not currently 
supported so the ARM configuration is not required in
[`deps/rootfs.conf`](../deps/rootfs.conf).

## Updating artifact configuration

Artifact configuration for the Lima bundle for Finch on macOS and the rootfs
for Finch on Windows is updated via the 
[update dependencies](../.github/workflows/update-dependencies.yaml)
GitHub Actions workflow. The workflow scans S3 for more up-to-date 
versions of the required dependency and opens a pull request with
the configuration updates.

Artifact configuration for the Finch on macOS virtual machine image
is still manually updated.
