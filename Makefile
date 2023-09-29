# Files are installed under $(DESTDIR)/$(PREFIX)
PREFIX ?= $(CURDIR)/_output
DEST := $(shell echo "$(DESTDIR)/$(PREFIX)" | sed 's:///*:/:g; s://*$$::')
OUTDIR ?= $(CURDIR)/_output
HASH_DIR ?= $(CURDIR)/hashes
DOWNLOAD_DIR := $(CURDIR)/downloads
OS_DOWNLOAD_DIR := $(DOWNLOAD_DIR)/os
LIMA_DOWNLOAD_DIR := $(DOWNLOAD_DIR)/dependencies
ROOTFS_DOWNLOAD_DIR := $(DOWNLOAD_DIR)/os
DEPENDENCIES_DOWNLOAD_DIR :=  $(DOWNLOAD_DIR)/dependencies
SOCKET_VMNET_TEMP_PREFIX ?= $(OUTDIR)/dependencies/lima-socket_vmnet/opt/finch
UNAME := $(shell uname -m)
ARCH ?= $(UNAME)
BUILD_TS := $(shell date +%s)

# Set these variables if they aren't set, or if they are set to ""
# Allows callers to override these default values
# From https://dl.fedoraproject.org/pub/fedora/linux/releases/37/Cloud/x86_64/images/
FINCH_OS_x86_URL := $(or $(FINCH_OS_x86_URL),https://deps.runfinch.com/Fedora-Cloud-Base-38-1.6.x86_64-20230830214712.qcow2)
FINCH_OS_x86_DIGEST := $(or $(FINCH_OS_x86_DIGEST),"sha256:e8d5872454cf25155ce5f19381f27ef096ce89efcbb5ecc639dcb6bf44e16bf8")
# From https://dl.fedoraproject.org/pub/fedora/linux/releases/37/Cloud/aarch64/images/
FINCH_OS_AARCH64_URL := $(or $(FINCH_OS_AARCH64_URL),https://deps.runfinch.com/Fedora-Cloud-Base-38-1.6.aarch64-20230830214718.qcow2)
FINCH_OS_AARCH64_DIGEST := $(or $(FINCH_OS_AARCH64_DIGEST),"sha256:219a30f1409f8757eaf654dabf378fe0412b9499f877e5c69ad2f24327b1a5f4")

FINCH_ROOTFS_x86_URL := $(or $(FINCH_ROOTFS_x86_URL),https://deps.runfinch.com/common/x86-64/finch-rootfs-production-amd64-1694791577.tar.gz)
FINCH_ROOTFS_x86_DIGEST := $(or $(FINCH_ROOTFS_x86_DIGEST),"sha256:2d4d2e7386450899c6d0587fd0db21afadb31d974fa744aa9365c883935c5341")

LIMA_DEPENDENCY_FILE_NAME ?= lima-and-qemu.tar.gz
.DEFAULT_GOAL := all

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
lima: lima-exe
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

.PHONE: install.lima-dependencies
install.lima-dependencies: download.lima-dependencies

.PHONY: lima-template
lima-template: download
	mkdir -p $(OUTDIR)/lima-template
	cp $(OUTDIR)/lima-template/$(FEDORA_YAML) $(OUTDIR)/lima-template/fedora.yaml
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
