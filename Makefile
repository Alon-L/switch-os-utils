LINUX_PATH ?= $(error Pass LINUX_PATH argument!)
LINUX_VERSION := $(shell cd $(LINUX_PATH); git describe --exact-match --tags)
LINUX_BUILD_DIR := build/$(LINUX_VERSION)

MMDEBSTRAP ?= mmdebstrap

MMDEBSTRAP_INCLUDES ?= openssh-server
MMDEBSTRAP_SUITE ?= stable

MMDEBSTRAP_FLAGS += --aptopt='Acquire::Languages { "environment"; "en"; }'
MMDEBSTRAP_FLAGS += --dpkgopt='path-exclude=/usr/share/man/*' \
	--dpkgopt='path-include=/usr/share/man/man[1-9]/*' \
	--dpkgopt='path-exclude=/usr/share/locale/*' \
	--dpkgopt='path-include=/usr/share/locale/locale.alias' \
	--dpkgopt='path-exclude=/usr/share/doc/*' \
	--dpkgopt='path-include=/usr/share/doc/*/copyright' \
	--dpkgopt='path-include=/usr/share/doc/*/changelog.Debian.*'

CWD := $(CURDIR)

build:
	mkdir -p $@

$(LINUX_BUILD_DIR): | build
	mkdir -p $@

build/initramfs: | build
	sudo $(MMDEBSTRAP) --include=$(MMDEBSTRAP_INCLUDES) $(MMDEBSTRAP_FLAGS) $(MMDEBSTRAP_SUITE) $@
	echo "echo 'switch-os' > /etc/hostname" | sudo chroot $@
	echo "echo 'root::0:0:root:/root:/bin/sh' > /etc/passwd" | sudo chroot $@
	echo "echo 'root::19341:0:99999:7:::' > /etc/shadow" | sudo chroot $@
	echo "echo -e 'auto enp0s3\niface enp0s3 inet dhcp' > /etc/network/interfaces" | sudo chroot $@
	echo "ln -s sbin/init init" | sudo chroot $@

build/initramfs.cpio.gz: build/initramfs
	cd $^; find . -print0 | cpio --null -ov --format=newc | gzip -9 > $(CWD)/$@

$(LINUX_BUILD_DIR)/bzImage: | $(LINUX_BUILD_DIR)
	$(MAKE) -C $(LINUX_PATH) defconfig
	$(MAKE) -C $(LINUX_PATH) bzImage
	cp $(LINUX_PATH)/arch/x86/boot/bzImage $@

$(LINUX_BUILD_DIR)/linux-headers/Module.symvers: $(LINUX_BUILD_DIR)/bzImage | $(LINUX_BUILD_DIR)
	mkdir -p $(@D)
	$(MAKE) -C $(LINUX_PATH) modules
	cp $(LINUX_PATH)/Module.symvers $@

$(LINUX_BUILD_DIR)/linux-headers: $(LINUX_BUILD_DIR)/linux-headers/Module.symvers | $(LINUX_BUILD_DIR)
	mkdir -p $@
	$(MAKE) -C $(LINUX_PATH) mrproper
	$(MAKE) -C $(LINUX_PATH) O=$(CWD)/$@ defconfig
	$(MAKE) -C $(LINUX_PATH) O=$(CWD)/$@ modules_prepare 
	rm -rf $@/source

$(LINUX_BUILD_DIR)/linux-headers.tar.gz: $(LINUX_BUILD_DIR)/linux-headers
	tar czf $@ $^

all: build/initramfs.cpio.gz $(LINUX_BUILD_DIR)/bzImage $(LINUX_BUILD_DIR)/linux-headers.tar.gz
.DEFAULT_GOAL := all

clean:
	rm -rf $(LINUX_BUILD_DIR)

clean-all:
	rm -rf build

.PHONY: all clean clean-all
