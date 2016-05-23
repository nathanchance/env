#!/bin/bash

# -----
# Usage
# -----
# $ . build_ak.sh <update|noupdate> <changelog|nochangelog>



# ------
# Colors
# ------
RED="\033[01;31m"
BLINK_RED="\033[05;31m"
RESTORE="\033[0m"



# ----------
# Parameters
# ----------
# FETCHUPSTREAM: Whether or not to fetch new AK updates
# CHANGELOG: Whether or not to build a changelog
FETCHUPSTREAM=${1}
CHANGELOG=${2}



# ---------
# Variables
# ---------
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
KERNEL="Image.gz"
DTBIMAGE="dtb"
DEFCONFIG="ak_angler_defconfig"
RESOURCE_DIR=~/Kernels
TOOLCHAIN_DIR=${RESOURCE_DIR}
KERNEL_DIR=~/Kernels/AK-Angler
ANYKERNEL_DIR=${RESOURCE_DIR}/AK-Angler-AnyKernel2
UPLOAD_DIR=~/shared/Kernels
KER_BRANCH=ak-mm-staging
AK_BRANCH=ak-angler-anykernel
BASE_AK_VER="AK"
VER=".066.ANGLER"
AK_VER="${BASE_AK_VER}${VER}"



# -------
# Exports
# -------
export LOCALVERSION=~`echo ${AK_VER}`
export CROSS_COMPILE="${TOOLCHAIN_DIR}/aarch64-linux-android-5.3-kernel/bin/aarch64-linux-android-"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=nathan
export KBUILD_BUILD_HOST=chancellor



# -----
# Paths
# -----
REPACK_DIR="${ANYKERNEL_DIR}"
PATCH_DIR="${ANYKERNEL_DIR}/patch"
MODULES_DIR="${ANYKERNEL_DIR}/modules"
ZIP_MOVE="${UPLOAD_DIR}"
ZIMAGE_DIR="${KERNEL_DIR}/arch/arm64/boot"



# ---------
# Functions
# ---------
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



# Clear the terminal
clear



# Time the start of the script
DATE_START=$(date +"%s")



# Show the version of the kernel compiling
echo -e ${RED}
echo -e "-------------------------------------------------------"
echo -e ""
echo -e "      ___    __ __    __ __ __________  _   __________ ";
echo -e "     /   |  / //_/   / //_// ____/ __ \/ | / / ____/ / ";
echo -e "    / /| | / ,<     / ,<  / __/ / /_/ /  |/ / __/ / /  ";
echo -e "   / ___ |/ /| |   / /| |/ /___/ _, _/ /|  / /___/ /___";
echo -e "  /_/  |_/_/ |_|  /_/ |_/_____/_/ |_/_/ |_/_____/_____/";
echo -e ""
echo -e ""
echo -e "-------------------------------------------------------"
echo -e ""
echo -e ""
echo -e ""
echo "---------------"
echo "KERNEL VERSION:"
echo "---------------"
echo -e ""

echo -e ${BLINK_RED}
echo -e ${AK_VER}
echo -e ${RESTORE}

echo -e ${RED}
echo -e "---------------------------------------------"
echo -e "BUILD SCRIPT STARTING AT $(date +%D\ %r)"
echo -e "---------------------------------------------"
echo -e ${RESTORE}



# Clean up
echo -e ${RED}
echo -e "-----------"
echo -e "CLEANING UP"
echo -e "-----------"
echo -e ${RESTORE}
echo -e ""

clean_all



# Update the git
echo -e ""
if [ "${FETCHUPSTREAM}" == "update" ]
then
   echo -e ${RED}
   echo -e "----------------"
   echo -e "UPDATING SOURCES"
   echo -e "----------------"
   echo -e ${RESTORE}

   update_git
fi



# Make the kernel
echo -e ${RED}
echo -e "-------------"
echo -e "MAKING KERNEL"
echo -e "-------------"
echo -e ${RESTORE}

make_kernel
make_dtb
make_modules
make_zip



# Make the changelog if requested
if [ ${CHANGELOG} == "changelog" ]
then
   echo -e ""
   echo -e ${RED}
   echo -e "----------------"
   echo -e "MAKING CHANGELOG"
   echo -e "----------------"
   echo -e ${RESTORE}

   . kernel_changelog.sh ak `date +"%m/%d/%y"` noupload

   echo -e ""
fi



# Upload
echo -e ${RED}
echo -e "------------------"
echo -e "UPLOADING ZIP FILE"
echo -e "------------------"
echo -e ${RESTORE}
echo -e ""

. ~/upload.sh



# End the script
echo -e ""
echo -e ${RED}
echo "--------------------"
echo "SCRIPT COMPLETED IN:"
echo "--------------------"

DATE_END=$(date +"%s")
DIFF=$((${DATE_END} - ${DATE_START}))

echo "TIME: $((${DIFF} / 60)) minute(s) and $((${DIFF} % 60)) seconds"

echo -e ${RESTORE}
echo -e "\a"
