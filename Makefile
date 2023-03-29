# Files are installed under $(DESTDIR)/$(PREFIX)
PREFIX ?= $(CURDIR)/_output
DEST := $(shell echo "$(DESTDIR)/$(PREFIX)" | sed 's:///*:/:g; s://*$$::')
OUTDIR ?= $(CURDIR)/_output
HASH_DIR ?= $(CURDIR)/hashes
DOWNLOAD_DIR := $(CURDIR)/downloads
OS_DOWNLOAD_DIR := $(DOWNLOAD_DIR)/os
SOCKET_VMNET_TEMP_PREFIX ?= $(OUTDIR)/dependencies/lima-socket_vmnet/opt/finch
UNAME := $(shell uname -m)
ARCH ?= $(UNAME)
BUILD_TS := $(shell date +%s)

# Set these variables if they aren't set, or if they are set to ""
# Allows callers to override these default values
# From https://dl.fedoraproject.org/pub/fedora/linux/releases/37/Cloud/x86_64/images/
FINCH_OS_x86_URL := $(or $(FINCH_OS_x86_URL),https://deps.runfinch.com/Fedora-Cloud-Base-37-1.7.x86_64-20230329185717.qcow2)
FINCH_OS_x86_DIGEST := $(or $(FINCH_OS_x86_DIGEST),"sha256:df67925e051ace602f58b1e01ed65156c975b985be1c0b24dd62f63d28d076d4")
# From https://dl.fedoraproject.org/pub/fedora/linux/releases/37/Cloud/aarch64/images/
FINCH_OS_AARCH64_URL := $(or $(FINCH_OS_AARCH64_URL),https://deps.runfinch.com/Fedora-Cloud-Base-37-1.7.aarch64-20230328221909.qcow2)
FINCH_OS_AARCH64_DIGEST := $(or $(FINCH_OS_AARCH64_DIGEST),"sha256:921a8901fd1913f508c9eeae79752f5274aab689dc6618a7141d151f9fddb11f")

.DEFAULT_GOAL := all

ifneq (,$(findstring arm64,$(ARCH)))
	LIMA_ARCH = aarch64
	FINCH_OS_BASENAME := $(notdir $(FINCH_OS_AARCH64_URL))
	FINCH_OS_IMAGE_URL := $(FINCH_OS_AARCH64_URL)
	FINCH_OS_DIGEST ?= $(FINCH_OS_AARCH64_DIGEST)
	HOMEBREW_PREFIX ?= /opt/homebrew
else ifneq (,$(findstring x86_64,$(ARCH)))
	LIMA_ARCH = x86_64
	FINCH_OS_BASENAME := $(notdir $(FINCH_OS_x86_URL))
	FINCH_OS_IMAGE_URL := $(FINCH_OS_x86_URL)
	FINCH_OS_DIGEST ?= $(FINCH_OS_x86_DIGEST)
	HOMEBREW_PREFIX ?= /usr/local
endif

FINCH_OS_IMAGE_LOCATION ?= $(OUTDIR)/os/$(FINCH_OS_BASENAME)
FINCH_OS_IMAGE_INSTALLATION_LOCATION ?= $(DEST)/os/$(FINCH_OS_BASENAME)

.PHONY: all
all: binaries

.PHONY: binaries
binaries: os lima-socket-vmnet lima-template

.PHONY: download.os
download.os:
	mkdir -p $(OS_DOWNLOAD_DIR)
	curl -L --fail $(FINCH_OS_IMAGE_URL) > "$(OS_DOWNLOAD_DIR)/$(FINCH_OS_BASENAME)"
	cd $(OS_DOWNLOAD_DIR) && shasum -a 512 --check $(HASH_DIR)/$(FINCH_OS_BASENAME).sha512 || exit 1

.PHONY: download
download: download.os

.PHONY: lima
lima:
	(cd src/lima && git clean -f -d)
	make -C src/lima PREFIX=$(HOMEBREW_PREFIX) all install

.PHONY: lima-template
lima-template: download
	mkdir -p $(OUTDIR)/lima-template
	cp lima-template/fedora.yaml $(OUTDIR)/lima-template
	# using -i.bak is very intentional, it allows the following commands to succeed for both GNU / BSD sed
	# this sed command uses the alternative separator of "|" because the image location uses "/"
	sed -i.bak -e "s|<image_location>|$(FINCH_OS_IMAGE_LOCATION)|g" $(OUTDIR)/lima-template/fedora.yaml
	sed -i.bak -e "s/<image_arch>/$(LIMA_ARCH)/g" $(OUTDIR)/lima-template/fedora.yaml
	sed -i.bak -e "s/<image_digest>/$(FINCH_OS_DIGEST)/g" $(OUTDIR)/lima-template/fedora.yaml
	rm $(OUTDIR)/lima-template/*.yaml.bak

.PHONY: lima-socket-vmnet
lima-socket-vmnet:
	git submodule update --init --recursive src/socket_vmnet
	cd src/socket_vmnet && git clean -f -d
	cd src/socket_vmnet && PREFIX=$(SOCKET_VMNET_TEMP_PREFIX) $(MAKE) install.bin

.PHONY: install-deps
install-deps: lima
	./bin/lima-and-qemu.pl
	mv src/lima/lima-and-qemu.tar.gz src/lima/lima-and-qemu.macos-${LIMA_ARCH}.${BUILD_TS}.tar.gz
	sha512sum src/lima/lima-and-qemu.macos-${LIMA_ARCH}.${BUILD_TS}.tar.gz | cut -d " " -f 1  > src/lima/lima-and-qemu.macos-${LIMA_ARCH}.${BUILD_TS}.tar.gz.sha512sum

.PHONY: download-sources
download-sources:
	./bin/download-sources.pl

.PHONY: os
os: download
	mkdir -p $(OUTDIR)/os
	lz4 -dcf $(DOWNLOAD_DIR)/os/$(FINCH_OS_BASENAME) > "$(OUTDIR)/os/$(FINCH_OS_BASENAME)"

.PHONY: install
install: uninstall
	mkdir -p $(DEST)
	(cd _output && tar c * | tar Cvx  $(DEST) )
	sed -i.bak -e "s|${FINCH_OS_IMAGE_LOCATION}|$(FINCH_OS_IMAGE_LOCATION)|g" $(DEST)/lima-template/fedora.yaml
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
	cd e2e && go test -v ./... -ginkgo.v