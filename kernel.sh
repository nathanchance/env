#!/bin/bash
#
# Flash compilation script for the Nexus 6P
#
# Copyright (C) 2016-2017 Nathan Chancellor
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>


###########
#         #
#  USAGE  #
#         #
###########

# PURPOSE: Build Flash Kernel and package it into a flashable zip
# USAGE:
# $ kernel.sh <angler|shamu> <release|staging> <tcupdate>
# $ kernel.sh me <tcupdate>


############
#          #
#  COLORS  #
#          #
############

RED="\033[01;31m"
BLINK_RED="\033[05;31m"
RESTORE="\033[0m"


###############
#             #
#  FUNCTIONS  #
#             #
###############

# SOURCE OUR UNIVERSAL FUNCTIONS SCRIPT
source $( dirname ${BASH_SOURCE} )/funcs.sh


################
#              #
#  PARAMETERS  #
#              #
################

# DEVICE (STRING): which device we are compiling for
# KERNEL_TYPE (STRING): the type of build we are compiling
# ANDROID_VERSION (STRING): Android version we are compiling for
# TCUPDATE (T/F): whether or not we are updating the toolchain before compiling

unset LOCALVERSION
unset PRIVATE
SUCCESS=false

while [[ $# -ge 1 ]]; do
    case "${1}" in
        "me")
            DEVICE=angler
            KERNEL_TYPE=personal
            ANDROID_VERSION=7.1.1
            export LOCALVERSION=-$( TZ=MST date +%Y%m%d ) ;;
        "shamu"|"angler"|"bullhead")
            DEVICE=${1} ;;
        "staging"|"release"|"testing"|"eas")
            KERNEL_TYPE=${1} ;;
        "7.1.1")
            ANDROID_VERSION=${1} ;;
        "private")
            PRIVATE=true ;;
        *)
            echo "Invalid parameter" && exit ;;
    esac

    shift
done

if [[ -z ${DEVICE} || -z ${KERNEL_TYPE} || -z ${ANDROID_VERSION} ]]; then
    echo "You did not specify a necessary parameter!" && exit
fi

case "${DEVICE}" in
    "bullhead"|"shamu")
        KERNEL_BRANCH=release-${ANDROID_VERSION} ;;
    "angler")
        KERNEL_BRANCH=n${ANDROID_VERSION}-flash ;;
esac

###############
#             #
#  VARIABLES  #
#             #
###############

# ANDROID_HEAD: head folder of all Android folders
# KERNEL_HEAD: head folder to all kernel folders
# ZIP_MOVE_HEAD: head folder to all the folders that hold completed zips
# TOOLCHAIN_HEAD: head folder for toolchains (also holds the source)
# ANYKERNEL_FOLDER: folder that holds AnyKernel source
# SOURCE_FOLDER: folder that holds kernel source
# ARCHITECTURE: architecture of the device we are compiling for
# KERNEL_IMAGE: name of the completed kernel image
# TOOLCHAIN_PREFIX: end of the toolchain name
# TOOLCHAIN_NAME: name of the toolchain we want to compile and use
# TOOLCHAIN_FOLDER: final location of the toolchain after compilation
# ZIP_MOVE: final location of the completed zip files
# ANYKERNEL_BRANCH: branch that we are using for our AnyKernel source
# THREADS: -j flag for make with the number of threads available
# DEFCONFIG: name of the defconfig we are using
# KERNEL: location of the kernel image after compilation


ANDROID_HEAD=${HOME}
KERNEL_HEAD=${ANDROID_HEAD}/Kernels
ZIP_MOVE_HEAD=${HOME}/Web
TOOLCHAIN_HEAD=${HOME}/Toolchains/Prebuilts
ANYKERNEL_FOLDER=${KERNEL_HEAD}/anykernel

DEFCONFIG=flash_defconfig

case "${DEVICE}" in
    "angler"|"bullhead")
        SOURCE_FOLDER=${KERNEL_HEAD}/${DEVICE}
        ARCHITECTURE=arm64
        KERNEL_IMAGE=Image.gz-dtb
        TOOLCHAIN_PREFIX=aarch64-linux-android-
        TOOLCHAIN_NAME=${TOOLCHAIN_PREFIX}6.x
        TOOLCHAIN_FOLDER=${TOOLCHAIN_HEAD}/${TOOLCHAIN_NAME} ;;
    "shamu")
        SOURCE_FOLDER=${KERNEL_HEAD}/${DEVICE}
        ARCHITECTURE=arm
        KERNEL_IMAGE=zImage-dtb
        TOOLCHAIN_PREFIX=arm-eabi-
        TOOLCHAIN_NAME=${TOOLCHAIN_PREFIX}6.x
        TOOLCHAIN_FOLDER=${TOOLCHAIN_HEAD}/${TOOLCHAIN_NAME} ;;
esac

case "${KERNEL_TYPE}" in
    "staging")
        ZIP_MOVE=${ZIP_MOVE_HEAD}/Kernels/${DEVICE}/${ANDROID_VERSION}/Beta
        ANYKERNEL_BRANCH=${DEVICE}-flash-release-${ANDROID_VERSION} ;;
    "release")
        ZIP_MOVE=${ZIP_MOVE_HEAD}/Kernels/${DEVICE}/${ANDROID_VERSION}/Stable
        ANYKERNEL_BRANCH=${DEVICE}-flash-release-${ANDROID_VERSION} ;;
    "testing")
        ZIP_MOVE=${ZIP_MOVE_HEAD}/Kernels/${DEVICE}/${ANDROID_VERSION}/Testing
        ANYKERNEL_BRANCH=${DEVICE}-flash-release-${ANDROID_VERSION} ;;
    "personal")
        if [[ ${PRIVATE} != true ]]; then
            ZIP_MOVE=${ZIP_MOVE_HEAD}/Kernels/${DEVICE}/${ANDROID_VERSION}/Personal
            ANYKERNEL_BRANCH=${DEVICE}-flash-personal-${ANDROID_VERSION}
        else
            ZIP_MOVE=${ZIP_MOVE_HEAD}/.superhidden/Kernels
            ANYKERNEL_BRANCH=${DEVICE}-flash-personal-${ANDROID_VERSION}-new
        fi ;;
esac

THREADS=-j$(grep -c ^processor /proc/cpuinfo)
KERNEL=${SOURCE_FOLDER}/arch/${ARCHITECTURE}/boot/${KERNEL_IMAGE}


################
#              #
# SCRIPT START #
#              #
################

# SET THE START OF THE SCRIPT
START=$( TZ=MST date +"%s" )


# SILENTLY SHIFT KERNEL BRANCHES
clear && cd "${SOURCE_FOLDER}"

# ONLY CHECKOUT IF WE ARE NOT CURRENTLY BISECTING
if [[ ! $(git status | grep "bisect") ]]; then
    git checkout ${KERNEL_BRANCH} > /dev/null 2>&1
fi

# SET KERNEL VERSION FROM MAKEFILE
KERNEL_VERSION=$( grep -r "EXTRAVERSION = -" ${SOURCE_FOLDER}/Makefile | sed 's/^.*F/F/' )
case ${KERNEL_TYPE} in
    "personal")
        ZIP_NAME=${KERNEL_VERSION}${LOCALVERSION}-$( TZ=MST date +%H%M ) ;;
    *)
        ZIP_NAME=${KERNEL_VERSION} ;;
esac


###################
# SHOW ASCII TEXT #
###################

echo -e ${RED}; newLine
echo -e "================================================================================================"; newLine; newLine
echo -e "  ___________________________________  __   ______ _______________________   ________________   "
echo -e "  ___  ____/__  /___    |_  ___/__  / / /   ___  //_/__  ____/__  __ \__  | / /__  ____/__  /   "
echo -e "  __  /_   __  / __  /| |____ \__  /_/ /    __  ,<  __  __/  __  /_/ /_   |/ /__  __/  __  /    "
echo -e "  _  __/   _  /___  ___ |___/ /_  __  /     _  /| | _  /___  _  _, _/_  /|  / _  /___  _  /___  "
echo -e "  /_/      /_____/_/  |_/____/ /_/ /_/      /_/ |_| /_____/  /_/ |_| /_/ |_/  /_____/  /_____/  "; newLine; newLine; newLine
echo -e "================================================================================================"; newLine; newLine


#########################
#  SHOW KERNEL VERSION  #
#########################

echoText "KERNEL VERSION"; newLine

echo -e ${RED}${ZIP_NAME}${RESTORE}; newLine


####################
# CLEANING FOLDERS #
####################

echoText "CLEANING UP"

# Cleaning of AnyKernel directory
cd "${ANYKERNEL_FOLDER}"
git checkout ${ANYKERNEL_BRANCH}
if [[ "${KERNEL_TYPE}" != "personal" ]]; then
    git reset --hard origin/${ANYKERNEL_BRANCH}
    git clean -f -d -x > /dev/null 2>&1
else
    rm -rf ${KERNEL_IMAGE}
fi

# Cleaning of kernel directory
cd "${SOURCE_FOLDER}"
if [[ "${KERNEL_TYPE}" != "personal" ]]; then
    git reset --hard origin/${KERNEL_BRANCH}
    git clean -f -d -x > /dev/null 2>&1; newLine
fi


#################
# MAKING KERNEL #
#################

echoText "MAKING KERNEL"

# TAG THE HEAD COMMIT WITH THE VERSION FIRST IF IT'S A PUBLIC BUILD
if [[ ${PRIVATE} != true ]]; then
    git tag -a "${ZIP_NAME}" -m "${ZIP_NAME}"
    git push origin --tags
fi

# PROPERLY POINT COMPILER TO TOOLCHAIN AND ARCHITECTURE
export CROSS_COMPILE=${TOOLCHAIN_FOLDER}/bin/${TOOLCHAIN_PREFIX}
export ARCH=${ARCHITECTURE}
export SUBARCH=${ARCHITECTURE}

# CLEAN PREVIOUSLY COMPILED FILES AND DEFCONFIG
make clean && make mrproper

# POINT TO PROPER DEFCONFIG
make ${DEFCONFIG}

# MAKE THE KERNEL
time make ${THREADS}


######################
# IF KERNEL COMPILED #
######################

if [[ $( ls ${KERNEL} 2>/dev/null | wc -l ) != "0" ]]; then
    # SET BUILD SUCCESS STRING AND SUCCESS VARIABLE
    BUILD_RESULT_STRING="BUILD SUCCESSFUL" && SUCCESS=true


    #####################
    # COPY KERNEL IMAGE #
    #####################

    newLine; echoText "MOVING $( echo ${KERNEL_IMAGE} | awk '{print toupper($0)}' ) ($( du -h "${KERNEL}" | awk '{print $1}' ))"
    cp "${KERNEL}" "${ANYKERNEL_FOLDER}"

    # MAKE ZIP_FORMAT VARIABLE
    ZIP_FORMAT=F*.zip

    # IF ZIPMOVE DOESN'T EXIST, MAKE IT; OTHERWISE, CLEAN IT
    if [[ ! -d "${ZIP_MOVE}" ]]; then
        mkdir -p "${ZIP_MOVE}"
    elif [[ ${PRIVATE} = true ]]; then
        rm -rf "${ZIP_MOVE}"/${ZIP_FORMAT}*
    fi

    # MOVE TO ANYKERNEL FOLDER
    cd "${ANYKERNEL_FOLDER}"


    #################
    # MAKE ZIP FILE #
    #################

    echoText "MAKING FLASHABLE ZIP"
    zip -r9 ${ZIP_NAME}.zip * -x README.md ${ZIP_NAME}.zip > /dev/null 2>&1


    #################
    # MOVE ZIP FILE #
    #################

    mv ${ZIP_NAME}.zip "${ZIP_MOVE}"


    ###################
    # GENERATE MD5SUM #
    ###################

    md5sum "${ZIP_MOVE}"/${ZIP_NAME}.zip > "${ZIP_MOVE}"/${ZIP_NAME}.zip.md5sum


    # CLEAN ZIMAGE-DTB FROM ANYKERNEL FOLDER AFTER ZIPPING AND MOVING
    rm -rf "${ANYKERNEL_FOLDER}"/Image.gz-dtb


###################
# IF BUILD FAILED #
###################

else
    BUILD_RESULT_STRING="BUILD FAILED"
    SUCCESS=false
fi


##############
# SCRIPT END #
##############

echoText "${BUILD_RESULT_STRING}!"

END=$( TZ=MST date +"%s" )


######################
# ENDING INFORMATION #
######################

# IF THE BUILD WAS SUCCESSFUL, PRINT FILE LOCATION, AND SIZE
if [[ ${SUCCESS} = true ]]; then
    echo -e ${RED}"FILE LOCATION: ${ZIP_MOVE}/${ZIP_NAME}.zip"
    echo -e "SIZE: $( du -h ${ZIP_MOVE}/${ZIP_NAME}.zip | awk '{print $1}' )"${RESTORE}
fi

# PRINT THE TIME THE SCRIPT FINISHED
# AND HOW LONG IT TOOK REGARDLESS OF SUCCESS
echo -e ${RED}"TIME: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
echo -e "DURATION: $( format_time ${END} ${START} )"${RESTORE}; newLine


##################
# LOG GENERATION #
##################

# DATE: BASH_SOURCE (PARAMETERS)
echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${1}" >> ${LOG}

# BUILD <SUCCESSFUL|FAILED> IN # MINUTES AND # SECONDS
echo -e "${BUILD_RESULT_STRING} IN $( format_time ${END} ${START} )" >> ${LOG}

# ONLY ADD A LINE ABOUT FILE LOCATION IF SCRIPT COMPLETED SUCCESSFULLY
if [[ ${SUCCESS} = true ]]; then
    # FILE LOCATION: PATH
    echo -e "FILE LOCATION: ${ZIP_MOVE}/${ZIP_NAME}.zip" >> ${LOG}
fi


########################
# ALERT FOR SCRIPT END #
########################

echo -e "\a" && cd ${HOME}
unset LOCALVERSION
