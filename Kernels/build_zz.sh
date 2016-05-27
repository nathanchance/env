#!/bin/bash

# -----
# Usage
# -----
# $ . build_zz.sh <update|noupdate> <changelog|nochangelog>



# ------
# Colors
# ------
RED="\033[01;31m"
RESTORE="\033[0m"



# ----------
# Parameters
# ----------
# FETCHUPSTREAM: Whether or not to fetch new AK updates
# CHANGELOG: Whether or not to build a changelog
FETCHUPSTREAM=${1}
# CHANGELOG=${2}



# ---------
# Variables
# ---------
SOURCEDIR=~/Kernels/ZZ
AKDIR=~/Kernels/ZZ-AK2
UPLOADDIR=~/shared/Kernels
ZIPNAME=ZZ_angler-R5
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
DEFCONFIG=zz_defconfig



# Toolchain and arch information
export CROSS_COMPILE=~/Kernels/AOSP-4.9/bin/aarch64-linux-android-
export ARCH=arm64
export SUBARCH=arm64



# Clear the terminal
clear



# Start tracking time and date to add to zip
START=$(date +%s)



# Clean up
echo -e ${RED}
echo -e "-----------"
echo -e "CLEANING UP"
echo -e "-----------"
echo -e ${RESTORE}
echo -e ""

cd ${AKDIR}
git reset --hard
git clean -f -d
git pull

cd ${SOURCEDIR}
git reset --hard
git clean -f -d
make clean
make mrproper



# Update kernel if requested
if [ "${FETCHUPSTREAM}" == "update" ]
then
   echo -e ""
   echo -e ${RED}
   echo -e "----------------"
   echo -e "UPDATING SOURCES"
   echo -e "----------------"
   echo -e ${RESTORE}
   echo -e ""

   git checkout marshmallow
   git fetch upstream
   git merge upstream/marshmallow
   git push
fi



# make kernel
echo -e ""
echo -e ${RED}
echo -e "-------------"
echo -e "MAKING KERNEL"
echo -e "-------------"
echo -e ${RESTORE}
echo -e ""

make ${DEFCONFIG}
make ${THREAD}



# Grab zImage-dtb
echo -e ${RED}
echo -e ""
echo -e "-----------------------"
echo -e "COLLECTING IMAGE.GZ-DTB"
echo -e "-----------------------"
echo -e ${RESTORE}

cp ${SOURCEDIR}/arch/arm64/boot/Image.gz-dtb ${AKDIR}/Image.gz-dtb



# Build Zip
echo -e ${RED}
echo -e "-----------------------"
echo -e "MAKING ${ZIPNAME}.ZIP" | tr [a-z] [A-Z]
echo -e "-----------------------"
echo -e ${RESTORE}

cd ${AKDIR}
zip -x@zipexclude -r9 `echo ${ZIPNAME}`.zip *



# Remove the previous zip and move the new zip into the upload directory
echo -e ""
echo -e ${RED}
echo -e "-----------------------"
echo -e "MOVING ${ZIPNAME}.ZIP" | tr [a-z] [A-Z]
echo -e "-----------------------"
echo -e ${RESTORE}

rm ${UPLOADDIR}/ZZ_*.zip
mv ${ZIPNAME}.zip ${UPLOADDIR}



# Upload it
echo -e ${RED}
echo -e "--------------------------"
echo -e "UPLOADING ${ZIPNAME}.ZIP" | tr [a-z] [A-Z]
echo -e "--------------------------"
echo -e ${RESTORE}
echo -e ""

. ~/upload.sh



# Go to the home directory
cd ~/



# Success! Stop tracking time
echo -e ""
echo -e ${RED}
echo "--------------------"
echo "SCRIPT COMPLETED IN:"
echo "--------------------"

END=$(date +%s)
DIFF=$((${END} - ${START}))

echo "TIME: $((${DIFF} / 60)) minute(s) and $((${DIFF} % 60)) seconds"

echo -e ${RESTORE}
echo -e "\a"
