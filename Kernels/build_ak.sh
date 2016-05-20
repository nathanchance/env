#!/bin/bash

# Usage
# $ . build_ak.sh <update|noupdate>

# Bash Color
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

# Clear the terminal
clear

# Resources
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
KERNEL="Image.gz"
DTBIMAGE="dtb"
DEFCONFIG="ak_angler_defconfig"
RESOURCE_DIR=~/Kernels
TOOLCHAIN_DIR=${RESOURCE_DIR}
KERNEL_DIR=~/Kernels/AK-Angler
ANYKERNEL_DIR=${RESOURCE_DIR}/AK-Angler-AnyKernel2
UPLOAD_DIR=~/shared/Kernels
FETCHUPSTREAM=$1
KER_BRANCH=ak-mm-staging
AK_BRANCH=ak-angler-anykernel

# Kernel Details
BASE_AK_VER="AK"
VER=".666.ANGLER"
AK_VER="${BASE_AK_VER}${VER}"

# Variables
export LOCALVERSION=~`echo ${AK_VER}`
export CROSS_COMPILE="${TOOLCHAIN_DIR}/aarch64-linux-android-5.3-kernel/bin/aarch64-linux-android-"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=nathan
export KBUILD_BUILD_HOST=chancellor

# Paths
REPACK_DIR="${ANYKERNEL_DIR}"
PATCH_DIR="${ANYKERNEL_DIR}/patch"
MODULES_DIR="${ANYKERNEL_DIR}/modules"
ZIP_MOVE="${UPLOAD_DIR}"
ZIMAGE_DIR="${KERNEL_DIR}/arch/arm64/boot"

# Functions
# Clean the out and AnyKernel dirs, reset the AnyKernel dir, and make clean
function clean_all {
   if [ -f "${MODULES_DIR}/*.ko" ]; then
     rm `echo ${MODULES_DIR}"/*.ko"`
   fi
   cd ${REPACK_DIR}
   rm -rf ${KERNEL}
   rm -rf ${DTBIMAGE}
   git checkout ${AK_BRANCH}
   git reset --hard > /dev/null 2>&1
   git clean -f -d > /dev/null 2>&1
   git pull
   cd ${KERNEL_DIR}
   echo
   make clean && make mrproper
}

# Fetch the latest updates
function update_git {
   echo
   cd ${KERNEL_DIR}
   git checkout ${KER_BRANCH}
   git fetch upstream
   git merge upstream/${KER_BRANCH}
   echo
}

# Make the kernel
function make_kernel {
   echo
   cd ${KERNEL_DIR}
   make ${DEFCONFIG}
   make ${THREAD}
   cp -vr ${ZIMAGE_DIR}/${KERNEL} ${REPACK_DIR}/zImage
}

# Make the modules
function make_modules {
   if [ -f "${MODULES_DIR}/*.ko" ]; then
      rm `echo ${MODULES_DIR}"/*.ko"`
   fi
   #find $MODULES_DIR/proprietary -name '*.ko' -exec cp -v {} $MODULES_DIR \;
   find ${KERNEL_DIR} -name '*.ko' -exec cp -v {} ${MODULES_DIR} \;
}

# Make the DTB file
function make_dtb {
   ${REPACK_DIR}/tools/dtbToolCM -v2 -o ${REPACK_DIR}/${DTBIMAGE} -s 2048 -p scripts/dtc/ arch/arm64/boot/dts/
}

# Make the zip file, remove the previous version and upload it
function make_zip {
   cd ${REPACK_DIR}
   zip -x@zipexclude -r9 `echo ${AK_VER}`.zip *
   rm  ${UPLOAD_DIR}/${BASE_AK_VER}*.zip
   mv  `echo ${AK_VER}`.zip ${ZIP_MOVE}
   cd ${KERNEL_DIR}
}

DATE_START=$(date +"%s")

echo -e "${red}"
echo "AK Kernel Creation Script:"
echo "    _____                         "
echo "   (, /  |              /)   ,    "
echo "     /---| __   _   __ (/_     __ "
echo "  ) /    |_/ (_(_(_/ (_/(___(_(_(_"
echo " ( /                              "
echo " _/                               "
echo

echo "---------------"
echo "Kernel Version:"
echo "---------------"

echo -e "${red}"; echo -e "${blink_red}"; echo "$AK_VER"; echo -e "${restore}";

echo -e "${red}"
echo "-----------------"
echo "Making AK Kernel:"
echo "-----------------"
echo -e "${restore}"

# Clean up
clean_all

echo

# Update the git
if [ "${FETCHUPSTREAM}" == "update" ]
then
   update_git
fi

# Make the kernel
make_kernel
make_dtb
make_modules
make_zip

# Upload
. ~/upload.sh

echo -e "${red}"
echo "-------------------"
echo "Build Completed in:"
echo "-------------------"

DATE_END=$(date +"%s")
DIFF=$((${DATE_END} - ${DATE_START}))
echo "Time: $((${DIFF} / 60)) minute(s) and $((${DIFF} % 60)) seconds."
echo -e "${restore}"
echo
