# mkosi OS Image Building for Finch

This directory contains the mkosi-based infrastructure for building Finch OS images using Amazon Linux 2023 as the base distribution.

Using [mkosi](https://github.com/systemd/mkosi) allows us to build bespoke OS images from the ground up, re-using common configuration as much as possible for our different targets.

## Key Components

### Configuration Files

At it's core, mkosi is based on configuration files. In our case, these configuration files are largely used to control which packages are installed for which images, and to run post-installation scripts to make sure our custom packages are installed properly. More information can be found in [mkosi's docs](https://github.com/systemd/mkosi/blob/main/mkosi/resources/man/mkosi.1.md).

- **`mkosi.conf`**: Main mkosi configuration defining Amazon Linux distribution settings
- **`mkosi.images/`**: Directory containing specialized [subimage configurations](https://github.com/systemd/mkosi/blob/main/mkosi/resources/man/mkosi.1.md#building-multiple-images):
  - `base/`: Base Amazon Linux 2023 image with essential packages
  - `base-with-kernel/`: Base image plus kernel components
  - `container-with-kernel/`: Container runtime with kernel support
  - `os-image/`: Final bootable disk image with EXT4 filesystem
  - `wsl-rootfs/`: Windows Subsystem for Linux rootfs configuration

### Build Infrastructure

- **`build.sh`**: Main build script that orchestrates the entire build process
  - Handles multi-architecture builds (x86_64/arm64)
  - Sets up QEMU emulation for cross-platform builds
  - Manages Docker BuildKit integration
  - Downloads and integrates third-party packages (cosign, docker-credential-pass)
  - Builds custom AL2023 packages

- **`install-mkosi.sh`**: Script to install mkosi and its dependencies
- **`mkosi.sh`**: Wrapper script for mkosi execution

### mkosi Amazon Linux 2023 Integration

- **`0001-Add-support-for-Amazon-Linux-2023.patch`**: Custom patch for mkosi adding comprehensive AL2023 support to mkosi, including:
  - New Amazon Linux distribution class in mkosi
  - Repository configuration for AL2023 packages
  - Architecture-specific configurations
  - EXT4 orphan_file compatibility fixes for AL2023's e2fsck version
  - Package management integration

This patch should be submitted to mkosi and upstreamed for ease of maintainability. It is based off of [this (now closed) PR](https://github.com/systemd/mkosi/pull/3784).

### Custom Package Building

- **`al2023-package-build/`**: Directory containing infrastructure for building custom AL2023 packages
  - `Dockerfile`: Multi-stage build environment for compiling packages
  - Custom patches and configurations
  - Integration with fuse-sshfs and cloud-init packages

This build step uses Docker to isolate AL2023 package builds for packages which are either not available on AL2023, like fuse-sshfs, or cloud-init, where the default AL2023 version isn't compatible with Lima.

### QEMU Integration

- **`binfmt/`**: Git submodule for QEMU binary format support
- Automated setup of QEMU static binaries for cross-platform emulation
- systemd binfmt.d configuration for seamless cross-architecture execution

## Architecture

### Multi-Image Build Strategy

The build process uses a "subimages" approach where each image builds upon the previous:

1. **base**: Core Amazon Linux 2023 with essential packages
2. **base-with-kernel**: Adds kernel and boot components
3. **container-with-kernel**: Container runtime preparation
4. **os-image**: Final bootable disk image with partitioning
5. **wsl-rootfs**: Root filesystem from base, with minor changes to make it integrate well with WSL

There are a few reasons for these sub-images:
1. Keep the configuration as centralized as possible. Really the only difference between the bootable `os-image` and the wsl-rootfs is that `os-image` has a bootloader and kernel, so they should build from almost exactly the same source.
2. Upload a scannable artifact (container-with-kernel) to ECR to leverage Inspector Scanning.
3. Speed up builds via incremental building.

### Filesystem Configuration

- **EXT4**: Primary filesystem with AL2023 compatibility
- **Unified Kernel Images (UKI)**: Modern boot approach with single .efi files
- **systemd-repart**: Configuration for partition table, using a GPT layout (ESP partition and root partiton)

## Key Features

### CI/CD Integration

- GitHub Actions workflow support (`build-os.yaml`)
- ECR cache integration for build acceleration

## Build Process

1. **Environment Setup**: Architecture detection and tool preparation
2. **QEMU Configuration**: Cross-platform emulation setup
3. **Custom Package Building**: AL2023-specific package compilation
4. **Base Image Creation**: Core system with Amazon Linux 2023
5. **Kernel Integration**: Boot components and kernel installation
6. **Container Runtime**: Docker/containerd preparation
7. **Final Image Assembly**: Bootable disk image with partitioning

## Usage

To build OS images:

```bash
# Set architecture (defaults to current system)
export ARCH=x86_64  # or aarch64

# Run the build process
# optionally, set ECR_CACHE_REPO=0123456789.dkr.ecr.us-west-2.amazonaws.com/build-cahce
# to make BuildKit cache builds which will significantly speed things up
./build.sh
```

The build process will:
1. Set up cross-platform build environment
2. Build necessary QEMU binaries
3. Create custom AL2023 packages
4. Build the complete OS image stack
5. Generate final bootable disk image

Here's an example command of how this can be run on a local machine, while skipping the `./build.sh` script (in case you already ran `build.sh` and the third-party artifacts are present):

```bash
# install mkosi (this can be omitted once the patch to add AL2023 to mkosi is upstreamed)
rm "$HOME/.local/bin/mkosi"                                                                                                         
rm -rf ./mkosi
mkdir -p "$HOME/.local/bin/"
export PATH="$HOME/.local/bin/:$PATH"
./deps/mkosi/install-mkosi.sh

# run build
cd ./deps/mkosi
sudo env PATH="/home/fedora/.local/bin/:$PATH" MKOSI_DNF=/usr/bin/dnf4 ./mkosi.sh --arch arm64 -- --image-id os-image
```