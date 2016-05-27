#!/bin/bash

# -----
# Usage
# -----
# $ . build_elite.sh <update|noupdate> <changelog|nochangelog>



# ------
# Colors
# ------
BLUE="\033[01;36m"
RESTORE="\033[0m"



# ----------
# Parameters
# ----------
# FETCHUPSTREAM: merge in new changes
FETCHUPSTREAM=${1}
CHANGELOG=${2}



# ---------
# Variables
# ---------
# SOURCEDIR: Path to build your kernel
# AKDIR: Directory for the AnyKernel updater
# UPLOADDIR: Upload directory
SOURCEDIR=~/Kernels/Elite
AKDIR=${SOURCEDIR}/packagesm
UPLOADDIR=~/shared/Kernels
BRANCH=Elite-merged



# Toolchain location and info
TOOLCHAIN=~/Kernels/Linaro-4.9/bin/aarch64-linux-android-
export ARCH=arm64
export SUBARCH=arm64



# Clear the terminal
clear



# Start tracking time and date to add to zip
START=$(date +%s)
today=$(date +"%m_%d_%Y")



# Change to source directory to start
cd ${SOURCEDIR}



# Show Elite logo to start
echo -e ${BLUE}
echo -e ""
echo -e "    ____   _      _   _____   ____    "
echo -e "   |  __| | |    | | |_   _| |  __|   "
echo -e "   | |__  | |    | |   | |   | |__    "
echo -e "   |  __| | |    | |   | |   |  __|   "
echo -e "   | |__  | |__  | |   | |   | |__    "
echo -e "   |____| |____| |_|   |_|   |____|   "
echo -e "      __       ________       __      "
echo -e "      \ ~~~___|   __   |___~~~ /      "
echo -e "       _----__|__|  |__|__----_       "
echo -e "       \~~~~~~|__    __|~~~~~~/       "
echo -e "        ------\  |  |  /------        "
echo -e "         \_____\ |__| /_____/         "
echo -e "                \____/                "
echo -e ""
echo -e ""
echo -e ""
echo -e "---------------------------------------------"
echo -e "BUILD SCRIPT STARTING AT $(date +%D\ %r)"
echo -e "---------------------------------------------"
echo -e ${RESTORE}



# Clean up
echo -e ${BLUE}
echo -e "-----------"
echo -e "CLEANING UP"
echo -e "-----------"
echo -e ${RESTORE}
echo -e ""

git reset --hard
git clean -f -d
git pull
make clean
make mrproper



# Update kernel if requested
if [ "${FETCHUPSTREAM}" == "update" ]
then
   echo -e ""
   echo -e ${BLUE}
   echo -e "----------------"
   echo -e "UPDATING SOURCES"
   echo -e "----------------"
   echo -e ${RESTORE}
   echo -e ""

   git checkout ${BRANCH}
   git fetch upstream
   git merge upstream/${BRANCH}
   git push
fi



# Setup the build
cd ${SOURCEDIR}/arch/arm64/configs/BBKconfigsM
for KERNELNAME in *
 do
  cd ${SOURCEDIR}



# Setup output directory
mkdir -p "out/${KERNELNAME}"
cp -R "${AKDIR}/system" out/${KERNELNAME}
cp -R "${AKDIR}/META-INF" out/${KERNELNAME}
cp -R "${AKDIR}/patch" out/${KERNELNAME}
cp -R "${AKDIR}/ramdisk" out/${KERNELNAME}
cp -R "${AKDIR}/tools" out/${KERNELNAME}
cp -R "${AKDIR}/anykernel.sh" out/${KERNELNAME}



# Flashable zip name
ZIPNAME=${KERNELNAME}-${today}



# remove backup files
find ./ -name '*~' | xargs rm



# make kernel
echo -e ""
echo -e ${BLUE}
echo -e "-------------"
echo -e "MAKING KERNEL"
echo -e "-------------"
echo -e ${RESTORE}
echo -e ""

make 'angler_defconfig'
make -j`grep 'processor' /proc/cpuinfo | wc -l` CROSS_COMPILE=${TOOLCHAIN}



# Grab zImage-dtb
echo -e ${BLUE}
echo -e ""
echo -e "-----------------------"
echo -e "Collecting Image.gz-dtb"
echo -e "-----------------------"
echo -e ${RESTORE}

cp ${SOURCEDIR}/arch/arm64/boot/Image.gz-dtb out/${KERNELNAME}/Image.gz-dtb

done



# Build Zip
echo -e ${BLUE}
echo -e "------------------------------------"
echo -e "MAKING ${ZIPNAME}.ZIP" | tr [a-z] [A-Z]
echo -e "------------------------------------"
echo -e ${RESTORE}

cd ${SOURCEDIR}/out/${KERNELNAME}/
7z a -tzip -mx5 "${ZIPNAME}.zip"



# Remove the previous zip and move the new zip into the upload directory
echo -e ""
echo -e ${BLUE}
echo -e "------------------------------------"
echo -e "MOVING ${ZIPNAME}.ZIP" | tr [a-z] [A-Z]
echo -e "------------------------------------"
echo -e ${RESTORE}

rm ${UPLOADDIR}/Elite_*.zip
mv ${ZIPNAME}.zip ${UPLOADDIR}



# Make the changelog if requested
if [ ${CHANGELOG} == "changelog" ]
then
   echo -e ${BLUE}
   echo -e "----------------"
   echo -e "MAKING CHANGELOG"
   echo -e "----------------"
   echo -e ${RESTORE}

   . kernel_changelog.sh elite `date +"%m/%d/%y"` noupload
fi



# Upload it
echo -e ${BLUE}
echo -e "---------------------------------------"
echo -e "UPLOADING ${ZIPNAME}.ZIP" | tr [a-z] [A-Z]
echo -e "---------------------------------------"
echo -e ${RESTORE}
echo -e ""

. ~/upload.sh



# Remove the out directory
rm -rf ${SOURCEDIR}/out



# Go to the home directory
cd ~/



# Success! Stop tracking time
echo -e ""
echo -e ${BLUE}
echo "--------------------"
echo "SCRIPT COMPLETED IN:"
echo "--------------------"

END=$(date +%s)
DIFF=$((${END} - ${START}))

echo "TIME: $((${DIFF} / 60)) minute(s) and $((${DIFF} % 60)) seconds"

echo -e ${RESTORE}
echo -e "\a"
