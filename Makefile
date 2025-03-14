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

build:
	mkdir -p $@

build/initramfs: | build
	$(MMDEBSTRAP) --include=$(MMDEBSTRAP_INCLUDES) $(MMDEBSTRAP_FLAGS) $(MMDEBSTRAP_SUITE) $@
	echo "echo 'switch-os' > /etc/hostname" | chroot $@
	echo "echo 'root::0:0:root:/root:/bin/sh' > /etc/passwd" | chroot $@
	echo "echo 'root::19341:0:99999:7:::' > /etc/shadow" | chroot $@
	echo "echo -e 'auto enp0s3\niface enp0s3 inet dhcp' > /etc/network/interfaces" | chroot $@
	echo "ln -s sbin/init init" | chroot $@

build/initramfs.cpio.gz: build/initramfs
	cd $^; find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../$(@F)

clean:
	rm -rf build

.PHONY: clean
