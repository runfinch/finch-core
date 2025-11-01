# finch-core

This repository contains the core dependencies for the project and is versioned/maintained separately from the the main CLI repository.

## Local Development

### Dependency Installation

Fetch dependencies first.

```
brew update
brew install go qemu bash coreutils autoconf automake
```

### Build core

Build project locally.

```
make
```

### Start Lima virtual machine

```
./_output/lima/bin/limactl start template://fedora --tty=false
```

### Run commands

Run and test any command you wish with the following.
```
./_output/lima/bin/limactl shell fedora nerdctl ...
```

### E2E Testing

Note that the vm instance is NOT expected to exist before running the tests, please ensure it is removed before running the tests.
```
./_output/lima/bin/limactl stop fedora
./_output/lima/bin/limactl remove fedora
```

### Maintaining QEMU Version

The version of QEMU that is shipped with finch is the same version that is installed on the GitHub action runners as part of the `release.yaml` workflow. The QEMU version that is installed (and therefore shipped) is configurable in the `deps/qemu.conf` file. We use homebrew to install QEMU on the runners and since homebrew updates its formula files in place, in order to pin a version of QEMU, we need to find a specific commit that corresponds to that version. To do that -

- Go to https://github.com/Homebrew/homebrew-core/commits/main/Formula/q/qemu.rb
- Find the commit for the specific version. For example - `6dd3cf36c974c9a69df5d2b0e5d3f4de3df30e77` for version `10.1.0`.
- Replace `QEMU_VERSION` and `QEMU_FORMULA_GH_COMMIT` with the appropriate values in the `deps/qemu.conf` file.
- Trigger the `release.yaml` or `Build` workflow.

**NOTE:** This version of QEMU is **not** the same as the version of QEMU that is installed inside the Finch VM. This is the QEMU version that will be used by Finch to launch the Finch VM when `vmType=qemu` is specified in `finch.yaml` configuration file.