#!/bin/bash

# -----
# Usage
# -----
# $ . build_ak.sh <update|noupdate> <toolchain>



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
# TOOLCHAIN: Toolchain to compile with
FETCHUPSTREAM=${1}
TOOLCHAIN=${2}



# ----------
# Directories
# ----------
RESOURCE_DIR=~/Kernels
KERNEL_DIR=${RESOURCE_DIR}/AK
ANYKERNEL_DIR=${RESOURCE_DIR}/AK-AK2
UPLOAD_DIR=~/shared/Kernels



# ---------
# Variables
# ---------
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
KERNEL="Image.gz"
DTBIMAGE="dtb"
DEFCONFIG="ak_angler_defconfig"
KER_BRANCH=ak-mm-staging
AK_BRANCH=ak-angler-anykernel
BASE_AK_VER="AK"
VER=".066.ANGLER"
if [ "${TOOLCHAIN}" == "aosp4.9" ]
then
   TOOLCHAIN_VER=".AOSP4.9"
   TOOLCHAIN_DIR=Toolchains/AOSP-4.9
elif [ "${TOOLCHAIN}" == "uber4.9" ]
then
   TOOLCHAIN_VER=".UBER4.9"
   TOOLCHAIN_DIR=Toolchains/UBER/out/aarch64-linux-android-4.9-kernel
elif [ "${TOOLCHAIN}" == "uber5.3" ]
then
   TOOLCHAIN_VER=".UBER5.3"
   TOOLCHAIN_DIR=Toolchains/UBER/out/aarch64-linux-android-5.x-kernel
elif [ "${TOOLCHAIN}" == "uber6.0" ]
then
   TOOLCHAIN_VER=".UBER6.0"
   TOOLCHAIN_DIR=Toolchains/UBER/out/aarch64-linux-android-6.x-kernel
elif [ "${TOOLCHAIN}" == "uber7.0" ]
then
   TOOLCHAIN_VER=".UBER7.0"
   TOOLCHAIN_DIR=Toolchains/UBER/out/aarch64-linux-android-7.0-kernel
fi
AK_VER="${BASE_AK_VER}${VER}${TOOLCHAIN_VER}"



# -------
# Exports
# -------
export LOCALVERSION=-`echo ${AK_VER}`
export CROSS_COMPILE="${RESOURCE_DIR}/${TOOLCHAIN_DIR}/bin/aarch64-linux-android-"
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
   git push
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
   rm  ${UPLOAD_DIR}/${BASE_AK_VER}*${TOOLCHAIN_VER}.zip
   mv  `echo ${AK_VER}`.zip ${UPLOAD_DIR}
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
