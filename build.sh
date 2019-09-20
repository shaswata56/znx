#! /bin/sh

# -- Variables passed by the docker command.

TRAVIS_COMMIT=$1
TRAVIS_BRANCH=$2


# -- Install dependencies.

apt-get -qq -y update > /dev/null
apt-get -qq -y install wget patchelf file libcairo2 > /dev/null
apt-get -qq -y install mtools xorriso axel gdisk zsync btrfs-progs dosfstools grub-common grub2-common grub-efi-amd64 grub-efi-amd64-bin > /dev/null
apt-get -qq -y install git autoconf gettext automake libtool-bin autopoint pkg-config libncurses5-dev bison > /dev/null

wget -q https://gitlab.com/nitrux/tools/build-utilities/raw/master/mkiso

wget -q http://mirrors.kernel.org/ubuntu/pool/main/u/util-linux/libmount1_2.33.1-0.1ubuntu2_amd64.deb
wget -q http://mirrors.kernel.org/ubuntu/pool/main/u/util-linux/libsmartcols1_2.33.1-0.1ubuntu2_amd64.deb
dpkg -i libmount1_2.33.1-0.1ubuntu2_amd64.deb
dpkg -i libsmartcols1_2.33.1-0.1ubuntu2_amd64.deb

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



export ARCH="$(arch)"
export VERSION="v0.0.1"

APP=cmake-tools
LOWERAPP=${APP,,}

mkdir -p "$HOME/$APP/$APP.AppDir/usr/"

BUILD_PATH="$(pwd)"

cd "$HOME/$APP/"

wget -q https://github.com/probonopd/AppImages/raw/master/functions.sh -O ./functions.sh
. ./functions.sh

cd $APP.AppDir

cp -r "${BUILD_PATH}/cmake" .
cp "${BUILD_PATH}/.clang-format" .
cp "${BUILD_PATH}/.clang-tidy" .
cp "${BUILD_PATH}/${LOWERAPP}" "AppRun"

########################################################################
# Copy desktop and icon file to AppDir for AppRun to pick them up
########################################################################

cp "${BUILD_PATH}/appimage/${LOWERAPP}.desktop" .
cp "${BUILD_PATH}/appimage/${LOWERAPP}.png" .

########################################################################
# Copy in the dependencies that cannot be assumed to be available
# on all target systems
########################################################################

copy_deps


########################################################################
# Patch away absolute paths; it would be nice if they were relative
########################################################################

find . -type f -exec sed -i -e 's|/usr|././|g' {} \;
find . -type f -exec sed -i -e 's@././/bin/env@/usr/bin/env@g' {} \;

########################################################################
# AppDir complete
# Now packaging it as an AppImage
########################################################################

cd .. # Go out of AppImage

mkdir -p ../out/
generate_type2_appimage
