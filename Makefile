# Files are installed under $(DESTDIR)/$(PREFIX)
PREFIX ?= $(CURDIR)/_output
DEST := $(shell echo "$(DESTDIR)/$(PREFIX)" | sed 's:///*:/:g; s://*$$::')
OUTDIR ?= $(CURDIR)/_output
HASH_DIR ?= $(CURDIR)/hashes
DOWNLOAD_DIR := $(CURDIR)/downloads
OS_DOWNLOAD_DIR := $(DOWNLOAD_DIR)/os
LIMA_DOWNLOAD_DIR := $(DOWNLOAD_DIR)/dependencies
LIMA_OUTDIR ?= $(OUTDIR)/lima
ROOTFS_DOWNLOAD_DIR := $(DOWNLOAD_DIR)/os
DEPENDENCIES_DOWNLOAD_DIR :=  $(DOWNLOAD_DIR)/dependencies
SOCKET_VMNET_TEMP_PREFIX ?= $(OUTDIR)/dependencies/lima-socket_vmnet/opt/finch
UNAME := $(shell uname -m)
ARCH ?= $(UNAME)
BUILD_TS := $(shell date +%s)

# Set these variables if they aren't set, or if they are set to ""
# Allows callers to override these default values
# From https://dl.fedoraproject.org/pub/fedora/linux/releases/37/Cloud/x86_64/images/
FINCH_OS_x86_URL := $(or $(FINCH_OS_x86_URL),https://deps.runfinch.com/Fedora-Cloud-Base-38-1.6.x86_64-20230918164920.qcow2)
FINCH_OS_x86_DIGEST := $(or $(FINCH_OS_x86_DIGEST),"sha256:214cce00ce5f6ac402a0a5a5269013eae201bf143ad8dbb9d50cfd5e22acd991")
# From https://dl.fedoraproject.org/pub/fedora/linux/releases/37/Cloud/aarch64/images/
FINCH_OS_AARCH64_URL := $(or $(FINCH_OS_AARCH64_URL),https://deps.runfinch.com/Fedora-Cloud-Base-38-1.6.aarch64-20230918164937.qcow2)
FINCH_OS_AARCH64_DIGEST := $(or $(FINCH_OS_AARCH64_DIGEST),"sha256:ad4c2fa3f80736cb6ea8e46f1a6ccf1f5f578e56de462bb60fcbc241786478d2")

FINCH_ROOTFS_x86_URL := $(or $(FINCH_ROOTFS_x86_URL),https://deps.runfinch.com/common/x86-64/finch-rootfs-production-amd64-1696963702.tar.gz)
FINCH_ROOTFS_x86_DIGEST := $(or $(FINCH_ROOTFS_x86_DIGEST),"sha256:ed36fb7f4819644efaf409a3417456fe8378c4f4bcff0bd1e0e520954b10ccf5")

LIMA_DEPENDENCY_FILE_NAME ?= lima-and-qemu.tar.gz
.DEFAULT_GOAL := all

WINGIT_TEMP_DIR := $(CURDIR)/wingit-temp
WINGIT_x86_URL := $(or $(WINGIT_x86_URL),https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.tar.bz2)
WINGIT_x86_BASENAME ?= $(notdir $(WINGIT_x86_URL))
WINGIT_x86_HASH := $(or $(WINGIT_x86_HASH),"sha256:c192e56f8ed3d364acc87ad04d1f5aa6ae03c23b32b67bf65fcc6f9b8f032e65")

ifneq (,$(findstring arm64,$(ARCH)))
	LIMA_ARCH = aarch64
	LIMA_URL ?= https://deps.runfinch.com/aarch64/lima-and-qemu.macos-aarch64.1691201350.tar.gz
	FINCH_OS_BASENAME := $(notdir $(FINCH_OS_AARCH64_URL))
	FINCH_OS_IMAGE_URL := $(FINCH_OS_AARCH64_URL)
	FINCH_OS_DIGEST ?= $(FINCH_OS_AARCH64_DIGEST)
	# TODO: Use Finch rootfs in Finch on Windows testing
	FINCH_ROOTFS_BASENAME := $(notdir $(FINCH_ROOTFS_AARCH64_URL))
	FINCH_ROOTFS_URL ?= $(FINCH_ROOTFS_AARCH64_URL)
	FINCH_ROOTFS_DIGEST ?= $(FINCH_ROOTFS_AARCH64_DIGEST)
	HOMEBREW_PREFIX ?= /opt/homebrew

else ifneq (,$(findstring x86_64,$(ARCH)))
	LIMA_ARCH = x86_64
	LIMA_URL ?= https://deps.runfinch.com/x86-64/lima-and-qemu.macos-x86_64.1691201350.tar.gz
	FINCH_OS_BASENAME := $(notdir $(FINCH_OS_x86_URL))
	FINCH_OS_IMAGE_URL := $(FINCH_OS_x86_URL)
	FINCH_OS_DIGEST ?= $(FINCH_OS_x86_DIGEST)
	# TODO: Use Finch rootfs in Finch on Windows testing
	FINCH_ROOTFS_BASENAME := $(notdir $(FINCH_ROOTFS_x86_URL))
	FINCH_ROOTFS_URL ?= $(FINCH_ROOTFS_x86_URL)
	FINCH_ROOTFS_DIGEST ?= $(FINCH_ROOTFS_x86_DIGEST)
	HOMEBREW_PREFIX ?= /usr/local

endif

FINCH_OS_IMAGE_LOCATION ?= $(OUTDIR)/os/$(FINCH_OS_BASENAME)
FINCH_OS_IMAGE_INSTALLATION_LOCATION ?= $(DEST)/os/$(FINCH_OS_BASENAME)

FINCH_ROOTFS_LOCATION ?= $(OUTDIR)/os/$(FINCH_ROOTFS_BASENAME)

.PHONY: all
all: binaries

.PHONY: binaries
.PHONY: download

# Rootfs required for Windows, require full OS for Linux and Mac
FINCH_IMAGE_LOCATION ?=
FINCH_IMAGE_DIGEST ?=
# ifeq ($(GOOS),windows)
#   FINCH_IMAGE_LOCATION := $(FINCH_ROOTFS_LOCATION)
#   FINCH_IMAGE_DIGEST := $(FINCH_ROOTFS_DIGEST)
# else
#   FINCH_IMAGE_LOCATION := $(FINCH_OS_IMAGE_LOCATION)
#   FINCH_IMAGE_DIGEST := $(FINCH_OS_DIGEST)
# endif

FEDORA_YAML ?=
BUILD_OS ?= $(OS)
ifeq ($(BUILD_OS), Windows_NT)
binaries: rootfs lima
download: download.rootfs
lima: lima-exe install.lima-dependencies-wsl2
FINCH_IMAGE_LOCATION := $(FINCH_ROOTFS_LOCATION)
FINCH_IMAGE_DIGEST := $(FINCH_ROOTFS_DIGEST)
else
binaries: os lima-socket-vmnet lima-template
download: download.os
FINCH_IMAGE_LOCATION := $(FINCH_OS_IMAGE_LOCATION)
FINCH_IMAGE_DIGEST := $(FINCH_OS_DIGEST)
FEDORA_YAML := fedora.yaml
endif

$(OS_DOWNLOAD_DIR)/$(FINCH_OS_BASENAME):
	mkdir -p $(OS_DOWNLOAD_DIR)
	curl -L --fail $(FINCH_OS_IMAGE_URL) > "$(OS_DOWNLOAD_DIR)/$(FINCH_OS_BASENAME)"
	cd $(OS_DOWNLOAD_DIR) && shasum -a 512 --check $(HASH_DIR)/$(FINCH_OS_BASENAME).sha512 || exit 1

$(ROOTFS_DOWNLOAD_DIR)/$(FINCH_ROOTFS_BASENAME):
	mkdir -p $(ROOTFS_DOWNLOAD_DIR)
	mkdir -p $(OUTDIR)/os
	curl -L --fail $(FINCH_ROOTFS_URL) > "$(ROOTFS_DOWNLOAD_DIR)/$(FINCH_ROOTFS_BASENAME)"
	cp $(ROOTFS_DOWNLOAD_DIR)/$(FINCH_ROOTFS_BASENAME) $(OUTDIR)/os


.PHONY: download.os
download.os: $(OS_DOWNLOAD_DIR)/$(FINCH_OS_BASENAME)

# TODO: getting sha PoC only for now
.PHONY: download.rootfs
download.rootfs: $(ROOTFS_DOWNLOAD_DIR)/$(FINCH_ROOTFS_BASENAME)
	$(eval FINCH_ROOTFS_DIGEST := "sha256:$(sha256 $(ROOTFS_DOWNLOAD_DIR)/$(FINCH_ROOTFS_BASENAME))")

$(LIMA_DOWNLOAD_DIR)/$(LIMA_DEPENDENCY_FILE_NAME):
	mkdir -p $(DEPENDENCIES_DOWNLOAD_DIR)
	curl -L --fail $(LIMA_URL) > "$(DEPENDENCIES_DOWNLOAD_DIR)/$(LIMA_DEPENDENCY_FILE_NAME)"
	mkdir -p ${OUTDIR}
	tar -xvzf ${DEPENDENCIES_DOWNLOAD_DIR}/${LIMA_DEPENDENCY_FILE_NAME} -C ${OUTDIR}

.PHONY: download.lima-dependencies
download.lima-dependencies: $(LIMA_DOWNLOAD_DIR)/$(LIMA_DEPENDENCY_FILE_NAME)

.PHONY: install.lima-dependencies
install.lima-dependencies: download.lima-dependencies

# Only redownload/extract if this file is missing (there's no particular reason for choosing this file instead of any other)
$(LIMA_OUTDIR)/bin/ssh.exe:
	mkdir -p $(DEPENDENCIES_DOWNLOAD_DIR)
	mkdir -p $(OUTDIR)/bin

	curl -L --fail $(WINGIT_x86_URL) > $(DEPENDENCIES_DOWNLOAD_DIR)/$(WINGIT_x86_BASENAME)
	pwsh.exe -NoLogo -NoProfile -c ./verify_hash.ps1 "$(DEPENDENCIES_DOWNLOAD_DIR)\$(WINGIT_x86_BASENAME)" $(WINGIT_x86_HASH)
	mkdir -p $(WINGIT_TEMP_DIR)
	# this takes a long time because of an almost 4:1 compression ratio and needing to extract many small files
	tar -xvjf "$(DEPENDENCIES_DOWNLOAD_DIR)\$(WINGIT_x86_BASENAME)" -C $(WINGIT_TEMP_DIR)
	
	# Lima runtime dependencies
	mkdir -p $(LIMA_OUTDIR)/bin

	# From https://packages.msys2.org/package/gzip?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/gzip.exe $(LIMA_OUTDIR)/bin/
	# From https://packages.msys2.org/package/msys2-runtime?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/cygpath.exe $(LIMA_OUTDIR)/bin/
	# From https://packages.msys2.org/package/tar?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/tar.exe $(LIMA_OUTDIR)/bin/
	# From https://packages.msys2.org/package/openssh?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/ssh.exe $(LIMA_OUTDIR)/bin/
	# From https://packages.msys2.org/package/openssh?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/ssh-keygen.exe $(LIMA_OUTDIR)/bin/
	
	# Dependency DLLs, extracted with https://github.com/lucasg/Dependencies
	# Dependencies.exe -chain $(WINGIT_TEMP_DIR)\usr\bin\ssh.exe -depth 3 -json
	# Depth 3 is only needed for ssh.exe, everything else only needs depth 1
	# TODO: Automate

	# Required by all MSYS2 programs, from https://github.com/msys2/msys2-runtime
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-2.0.dll $(LIMA_OUTDIR)/bin/
	# Required by tar.exe, from https://packages.msys2.org/package/libiconv?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-iconv-2.dll $(LIMA_OUTDIR)/bin/
	# Required by msys-iconv-2.dll, from https://packages.msys2.org/package/libintl?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-intl-8.dll $(LIMA_OUTDIR)/bin/
	# GCC exception handling, required for all programs that throw exceptions, from https://packages.msys2.org/package/gcc-libs?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-gcc_s-seh-1.dll $(LIMA_OUTDIR)/bin/

	# Required by ssh.exe, from https://packages.msys2.org/package/libopenssl?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-crypto-3.dll $(LIMA_OUTDIR)/bin/
	# Required by ssh-keygen.exe, from https://packages.msys2.org/package/libopenssl?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-crypto-1.1.dll $(LIMA_OUTDIR)/bin/
	# Required by ssh.exe, from https://packages.msys2.org/package/zlib-devel?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-z.dll $(LIMA_OUTDIR)/bin/
	# Required by ssh.exe, from https://packages.msys2.org/package/libcrypt?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-crypt-0.dll $(LIMA_OUTDIR)/bin/
	# Required by heimdal-libs, from https://packages.msys2.org/package/libsqlite?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-sqlite3-0.dll $(LIMA_OUTDIR)/bin/

	# Required by ssh.exe, from https://packages.msys2.org/package/heimdal-libs?repo=msys&variant=x86_64
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-asn1-8.dll $(LIMA_OUTDIR)/bin/
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-com_err-1.dll $(LIMA_OUTDIR)/bin/
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-gssapi-3.dll $(LIMA_OUTDIR)/bin/
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-hcrypto-4.dll $(LIMA_OUTDIR)/bin/
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-heimbase-1.dll $(LIMA_OUTDIR)/bin/
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-heimntlm-0.dll $(LIMA_OUTDIR)/bin/
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-hx509-5.dll $(LIMA_OUTDIR)/bin/
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-krb5-26.dll $(LIMA_OUTDIR)/bin/
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-roken-18.dll $(LIMA_OUTDIR)/bin/
	cp $(WINGIT_TEMP_DIR)/usr/bin/msys-wind-0.dll $(LIMA_OUTDIR)/bin/

	-@rm -rf $(WINGIT_TEMP_DIR)

.PHONY: install.lima-dependencies-wsl2
install.lima-dependencies-wsl2: $(LIMA_OUTDIR)/bin/ssh.exe

.PHONY: lima-template
lima-template: download
	mkdir -p $(OUTDIR)/lima-template
	cp lima-template/fedora.yaml $(OUTDIR)/lima-template
	# using -i.bak is very intentional, it allows the following commands to succeed for both GNU / BSD sed
	# this sed command uses the alternative separator of "|" because the image location uses "/"
	sed -i.bak -e "s|<image_location>|$(FINCH_IMAGE_LOCATION)|g" $(OUTDIR)/lima-template/fedora.yaml
	sed -i.bak -e "s/<image_arch>/$(LIMA_ARCH)/g" $(OUTDIR)/lima-template/fedora.yaml
	sed -i.bak -e "s/<image_digest>/$(FINCH_IMAGE_DIGEST)/g" $(OUTDIR)/lima-template/fedora.yaml
	rm $(OUTDIR)/lima-template/*.yaml.bak

.PHONY: lima-socket-vmnet
lima-socket-vmnet:
	git submodule update --init --recursive src/socket_vmnet
	cd src/socket_vmnet && git clean -f -d
	cd src/socket_vmnet && PREFIX=$(SOCKET_VMNET_TEMP_PREFIX) "$(MAKE)" install.bin

.PHONY: lima lima-exe
lima-exe:
	cd src/lima && \
	"$(MAKE)" exe _output/share/lima/lima-guestagent.Linux-x86_64
	mkdir -p ${OUTDIR}/lima
	cp -r src/lima/_output/* ${OUTDIR}/lima

.PHONY: download-sources
download-sources:
	./bin/download-sources.pl

.PHONY: os
os: download
	mkdir -p $(OUTDIR)/os
	lz4 -dcf $(DOWNLOAD_DIR)/os/$(FINCH_OS_BASENAME) > "$(OUTDIR)/os/$(FINCH_OS_BASENAME)"

.PHONY: rootfs
rootfs: download
	mkdir -p $(OUTDIR)/os
	cp $(DOWNLOAD_DIR)/os/$(FINCH_ROOTFS_BASENAME) "$(OUTDIR)/os/$(FINCH_ROOTFS_BASENAME)"

.PHONY: install
install: uninstall
	mkdir -p $(DEST)
	(cd _output && tar c * | tar Cvx  $(DEST) )
	sed -i.bak -e "s|${FINCH_OS_IMAGE_LOCATION}|$(FINCH_IMAGE_LOCATION)|g" $(DEST)/lima-template/fedora.yaml
	rm $(DEST)/lima-template/*.yaml.bak

.PHONY: uninstall
uninstall:
	-@rm -rf $(DEST)/dependencies 2>/dev/null || true
	-@rm -rf $(DEST)/lima 2>/dev/null || true
	-@rm -rf $(DEST)/lima-template 2>/dev/null || true
	-@rm -rf $(DEST)/os 2>/dev/null || true

.PHONY: clean
clean:
	-@rm -rf $(OUTDIR) 2>/dev/null || true
	-@rm -rf $(DOWNLOAD_DIR) 2>/dev/null || true
	-@rm ./*.tar.gz 2>/dev/null || true

.PHONY: test-e2e
test-e2e:
	cd e2e && go test -timeout 30m -v ./... -ginkgo.v
