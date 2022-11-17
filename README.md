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

