#! /bin/sh

# -- Variables passed by the docker command.

TRAVIS_COMMIT=$1
TRAVIS_BRANCH=$2


# -- Install dependencies.

apt-get -qq -y update > /dev/null
apt-get -qq -y install wget patchelf file libcairo2 > /dev/null
apt-get -qq -y install mtools xorriso axel gdisk zsync btrfs-progs dosfstools grub-common grub2-common grub-efi-amd64 grub-efi-amd64-bin > /dev/null

apt-get -qq -y install git autoconf gettext automake libtool-bin autopoint pkg-config libncurses5-dev bison > /dev/null

wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
wget -q https://gitlab.com/nitrux/tools/build-utilities/raw/master/copier
wget -q https://gitlab.com/nitrux/tools/build-utilities/raw/master/mkiso

wget -q http://mirrors.kernel.org/ubuntu/pool/main/u/util-linux/libmount1_2.33.1-0.1ubuntu2_amd64.deb
wget -q http://mirrors.kernel.org/ubuntu/pool/main/u/util-linux/libsmartcols1_2.33.1-0.1ubuntu2_amd64.deb
dpkg -i libmount1_2.33.1-0.1ubuntu2_amd64.deb
dpkg -i libsmartcols1_2.33.1-0.1ubuntu2_amd64.deb

chmod +x appimagetool
chmod +x copier
chmod +x mkiso
chmod +x appdir/znx

# -- Build util-linux 2.33

git clone https://github.com/karelzak/util-linux.git --depth 1 --branch stable/v2.33

(
	cd util-linux

	./autogen.sh
	./configure

	make -j$(nproc)
	make -j$(nproc) install
)

 # Remove old libsmartcols libraries for lsblk to find the correct one
rm /lib/x86_64-linux-gnu/libsmartcols.so.1*
rm /lib/x86_64-linux-gnu/libmount.so.1*

# -- Write the commit that generated this build.

sed -i "s/@TRAVIS_COMMIT@/${TRAVIS_COMMIT:0:7}/" appdir/znx


# -- Copy binaries and its dependencies to appdir.

./copier mkiso appdir
./copier axel appdir
./copier mcopy appdir
./copier zsync appdir
./copier lsblk appdir
./copier sgdisk appdir
./copier wipefs appdir
./copier xorriso appdir
./copier mkfs.vfat appdir
./copier mkfs.btrfs appdir


# -- Build GRUB's boot image.

grub-mkimage \
	-C xz \
	-O x86_64-efi \
	-o appdir/bootx64.efi \
	-p /boot/grub \
	boot linux search normal configfile \
	part_gpt btrfs ext2 fat iso9660 loopback \
	test keystatus gfxmenu regexp probe \
	efi_gop efi_uga all_video gfxterm font \
	echo read ls cat png jpeg halt reboot


# -- Generate the AppImage.

(
	cd appdir

	wget -q https://raw.githubusercontent.com/AppImage/AppImages/master/functions.sh
	chmod +x functions.sh
	. ./functions.sh
	delete_blacklisted
	rm functions.sh

	find lib/x86_64-linux-gnu -type f -exec patchelf --set-rpath '$ORIGIN/././' {} \;
	find bin -type f -exec patchelf --set-rpath '$ORIGIN/../lib/x86_64-linux-gnu' {} \;
	find sbin -type f -exec patchelf --set-rpath '$ORIGIN/../lib/x86_64-linux-gnu' {} \;
	find usr/bin -type f -exec patchelf --set-rpath '$ORIGIN/../../lib/x86_64-linux-gnu' {} \;
	find usr/sbin -type f -exec patchelf --set-rpath '$ORIGIN/../../lib/x86_64-linux-gnu' {} \;
)

wget -q https://raw.githubusercontent.com/Nitrux/appimage-wrapper/master/appimage-wrapper
chmod a+x appimage-wrapper

UPDATE_URL="zsync|https://github.com/Nitrux/znx/releases/download/continuous-development/znx_$TRAVIS_BRANCH"

mkdir out
ARCH=x84_64 ./appimage-wrapper appimagetool -u "$UPDATE_URL" appdir out/znx_$TRAVIS_BRANCH
