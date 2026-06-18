EMPTY :=
SPACE := $(EMPTY) $(EMPTY)
COMMA := ,

MM_EXTRA_OPTIONS ?= 
MM_OPTIONS := --arch=loong64 --mode=unshare --keyring=./keyring --dpkgopt='force-confnew' \
--customize-hook='rm -f "$$1"/etc/{dpkg/dpkg.cfg.d,apt/apt.conf.d}/99mmdebstrap' $(MM_EXTRA_OPTIONS)

PVE_CDID = $(strip $(file < pve-cd-id.txt))

.DELETE_ON_ERROR:

all: pve-installer.iso

/tmp/pve-installer.hook.sh: REL_INFO_B64 = $(shell base64 -w0 release.info)

/tmp/pve-installer.hook.sh: pve-installer.hook.sh.in release.info pve-cd-id.txt
	sed -e 's|@CDID@|$(PVE_CDID)|g' -e 's|@REL_INFO_B64@|$(REL_INFO_B64)|g' $< > $@

build:
	mkdir -pv build

build/pve-installer.squashfs: PACKAGE_LIST = $(subst $(SPACE),$(COMMA),$(sort $(file < pve-installer.list)))
build/pve-installer.squashfs: pve-loong64.sources pve-installer.list /tmp/pve-installer.hook.sh build pve-iso-init
	mmdebstrap $(MM_OPTIONS) --include='$(PACKAGE_LIST)' --customize-hook='upload pve-iso-init /usr/sbin/pve-iso-init' \
		--customize=/tmp/pve-installer.hook.sh \
		trixie $@ "$<"

build/pve-base.squashfs: PACKAGE_LIST = $(subst $(SPACE),$(COMMA),$(sort $(file < pve-base.list)))
build/pve-base.squashfs: pve-loong64.sources build pve-base.list
	mmdebstrap $(MM_OPTIONS) --include='$(PACKAGE_LIST)' --variant=required \
		trixie $@ "$<"

build/.disk: release.info build pve-cd-id.txt
	rm -rf build/.disk && mkdir -p build/.disk
	touch build/.disk/$$(date --utc +'%Y-%m-%d-%H-%M-%S.uuid')
	cp -v release.info build/.disk/info
	cp -v release.info build/.cd-info
	cp -v pve-cd-id.txt build/.pve-cd-id.txt
	rsync -av $(CURDIR)/files/ $(CURDIR)/build/
	mkdir -pv build/{.base,.installer,.installer-mp,.workdir}
	mkdir -pv build/dists/trixie/pve/binary-loong64
	mkdir -pv build/proxmox/packages
	echo 12035 > build/proxmox/pve-base.cnt

build/boot/linux26: build/pve-installer.squashfs
	rm -rf /tmp/pve-iso-tmp && unsquashfs -d /tmp/pve-iso-tmp $< /boot
	cp -v /tmp/pve-iso-tmp/boot/vmlinuz-*-pve build/boot/linux26
	cp -v /tmp/pve-iso-tmp/boot/initrd.img-*-pve build/boot/initrd.img

memtest86+loong64.deb:
	wget http://ftp.cn.debian.org/debian/pool/main/m/memtest86+/memtest86+_8.10-2_loong64.deb -O $@

build/boot/memtest86+loong64: memtest86+loong64.deb build
	rm -rf /tmp/pve-iso-deb-tmp/ && dpkg-deb -x $< /tmp/pve-iso-deb-tmp/
	cp -v /tmp/pve-iso-deb-tmp/boot/mt86+ $@
	rm -rf /tmp/pve-iso-deb-tmp/

pve-installer.iso: build/pve-installer.squashfs build/pve-base.squashfs build/.disk build/boot/linux26 build/boot/memtest86+loong64
	mkdir -p dist
	grub-mkrescue -o $@ build/ -- -as mkisofs -V "PVE" -R

clean:
	rm -rf build dist *.iso *.deb

.PHONY: clean
