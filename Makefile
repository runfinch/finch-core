# Files are installed under $(DESTDIR)/$(PREFIX)
PREFIX ?= $(CURDIR)/_output
DEST := $(shell echo "$(DESTDIR)/$(PREFIX)" | sed 's:///*:/:g; s://*$$::')
OUTDIR ?= $(CURDIR)/_output
DOWNLOAD_DIR := $(CURDIR)/downloads
LIMA_DOWNLOAD_DIR := $(DOWNLOAD_DIR)/dependencies
LIMA_OUTDIR ?= $(OUTDIR)/lima
UNAME := $(shell uname -m)
ARCH ?= $(UNAME)
BUILD_TS := $(shell date +%s)

OUTPUT_DIRECTORIES=$(OUTDIR) $(DOWNLOAD_DIR) $(LIMA_DOWNLOAD_DIR) $(LIMA_OUTDIR)

LIMA_DEPENDENCY_FILE_NAME ?= lima-and-qemu.tar.gz
.DEFAULT_GOAL := all

.PHONY: all
all: install.dependencies

# install.dependencies is a make target defined by the respective platform makefile
# pull the required finch core dependencies for the platform.
.PHONY: install.dependencies

# Rootfs required for Windows, require full OS for Mac
FINCH_IMAGE_LOCATION ?=
FINCH_IMAGE_DIGEST ?=
FINCH_VM_TYPE ?=
BUILD_OS ?= $(OS)
ifeq ($(BUILD_OS), Windows_NT)
include Makefile.windows
else
include Makefile.darwin
endif

$(OUTPUT_DIRECTORIES):
	@mkdir -p $@

.PHONY: download-sources
download-sources:
	./bin/download-sources.pl

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
test-e2e: $(LIMA_TEMPLATE_OUTDIR)/fedora.yaml
	cd e2e && VM_TYPE=$(FINCH_VM_TYPE) go test -timeout 30m -v ./... -ginkgo.v
