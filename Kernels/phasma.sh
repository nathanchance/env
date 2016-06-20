#!/bin/bash

# -----
# Usage
# -----
# $ . phasma.sh <update|noupdate> <toolchain>



# ------
# Colors
# ------
RED="\033[01;31m"
BLINK_RED="\033[05;31m"
RESTORE="\033[0m"



# ----------
# Parameters
# ----------
# FETCHUPSTREAM: Whether or not to fetch new Phasma updates
# TOOLCHAIN: Toolchain to compile with
FETCHUPSTREAM=${1}
TOOLCHAIN=${2}



# ----------
# Directories
# ----------
ANDROID_DIR=${HOME}
RESOURCE_DIR=${ANDROID_DIR}/Kernels
KERNEL_DIR=${RESOURCE_DIR}/Phasma
ZIMAGE_DIR="${KERNEL_DIR}/arch/arm64/boot"
ANYKERNEL_DIR=${KERNEL_DIR}/out
ZIP_MOVE=${HOME}/shared/Kernels/bullhead



# ---------
# Variables
# ---------
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
KERNEL="Image.gz-dtb"
DEFCONFIG="phasma_defconfig"
BASE_PHASMA_VER="Phasma"
VER=".R20.M.bullhead."
if [ "${TOOLCHAIN}" == "aosp" ]
then
   TOOLCHAIN_VER="AOSP4.9"
   TOOLCHAIN_DIR=Toolchains/AOSP
elif [ "${TOOLCHAIN}" == "uber4" ]
then
   TOOLCHAIN_VER="UBER4.9"
   TOOLCHAIN_DIR=Toolchains/UBER/4.9
elif [ "${TOOLCHAIN}" == "uber5" ]
then
   TOOLCHAIN_VER="UBER5.4"
   TOOLCHAIN_DIR=Toolchains/UBER/5.4
elif [ "${TOOLCHAIN}" == "uber6" ]
then
   TOOLCHAIN_VER="UBER6.1"
   TOOLCHAIN_DIR=Toolchains/UBER/6.1
elif [ "${TOOLCHAIN}" == "uber7" ]
then
   TOOLCHAIN_VER="UBER7.0"
   TOOLCHAIN_DIR=Toolchains/UBER/7.0
elif [ "${TOOLCHAIN}" == "linaro4.9" ]
then
   TOOLCHAIN_VER="LINARO4.9"
   TOOLCHAIN_DIR=Toolchains/Linaro/4.9
 elif [ "${TOOLCHAIN}" == "linaro5.3" ]
 then
   TOOLCHAIN_VER="LINARO5.3"
   TOOLCHAIN_DIR=Toolchains/Linaro/5.3
elif [ "${TOOLCHAIN}" == "linaro6.1" ]
then
   TOOLCHAIN_VER="LINARO6.1"
   TOOLCHAIN_DIR=Toolchains/Linaro/6.1
fi
PHASMA_VER="${BASE_PHASMA_VER}${VER}${TOOLCHAIN_VER}"



# -------
# Exports
# -------
export LOCALVERSION=-`echo ${PHASMA_VER}`
export CROSS_COMPILE="${RESOURCE_DIR}/${TOOLCHAIN_DIR}/bin/aarch64-linux-android-"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=nathan
export KBUILD_BUILD_HOST=chancellor
# Export the COMPILE_LOG variable for other files to use (I currently handle this via .bashrc)
# export LOGDIR=${HOME}/Logs
# export COMPILE_LOG=${LOGDIR}/compile_log_`date +%m_%d_%y`.log


# ---------
# Functions
# ---------
# Clean the out and AnyKernel dirs, reset the AnyKernel dir, and make clean
function clean_all {
   cd ${KERNEL_DIR}
   echo
   make clean
   make mrproper
   rm -rf ${KERNEL_DIR}/out/kernel/zImage
   git clean -f -d
   git reset --hard
}

# Make the kernel
function make_kernel {
   echo
   cd ${KERNEL_DIR}
   make ${DEFCONFIG}
   make ${THREAD}
}

# Make the zip file, remove the previous version and upload it
function make_zip {
   cp -vr ${ZIMAGE_DIR}/${KERNEL} ${ANYKERNEL_DIR}/kernel/zImage
   cd ${ANYKERNEL_DIR}
   zip -r9 `echo ${PHASMA_VER}`.zip *
   rm  ${ZIP_MOVE}/${BASE_PHASMA_VER}*${TOOLCHAIN_VER}.zip
   mv  `echo ${PHASMA_VER}`.zip ${ZIP_MOVE}
   cd ${KERNEL_DIR}
}



# Clear the terminal
clear



# Time the start of the script
DATE_START=$(date +"%s")



# Show the version of the kernel compiling
echo -e ${RED}
echo -e ""
echo -e ""
echo "----------------------"
echo "PHASMA KERNEL VERSION:"
echo "----------------------"
echo -e ""

echo -e ${BLINK_RED}
echo -e ${PHASMA_VER}
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

   git pull
   echo -e ""
fi



# Make the kernel
echo -e ${RED}
echo -e "-------------"
echo -e "MAKING KERNEL"
echo -e "-------------"
echo -e ${RESTORE}

make_kernel



# If the above was successful
if [ `ls ${ZIMAGE_DIR}/${KERNEL} 2>/dev/null | wc -l` != "0" ]
then
   BUILD_SUCCESS_STRING="BUILD SUCCESSFUL"

   make_zip

   # Upload
   echo -e ${RED}
   echo -e "------------------"
   echo -e "UPLOADING ZIP FILE"
   echo -e "------------------"
   echo -e ${RESTORE}
   echo -e ""

   . ${HOME}/upload.sh
else
   BUILD_SUCCESS_STRING="BUILD FAILED"
fi



# End the script
echo -e ""
echo -e ${RED}
echo "--------------------"
echo "SCRIPT COMPLETED IN:"
echo "--------------------"

DATE_END=$(date +"%s")
DIFF=$((${DATE_END} - ${DATE_START}))

echo -e "${BUILD_SUCCESS_STRING}!"
echo -e "TIME: $((${DIFF} / 60)) MINUTES AND $((${DIFF} % 60)) SECONDS"

echo -e ${RESTORE}

# Add line to compile log
echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${TOOLCHAIN_VER}" >> ${COMPILE_LOG}
echo -e "${BUILD_SUCCESS_STRING} IN $((${DIFF} / 60)) MINUTES AND $((${DIFF} % 60)) SECONDS\n" >> ${COMPILE_LOG}

echo -e "\a"
