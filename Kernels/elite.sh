#!/bin/bash

# -----
# Usage
# -----
# $ . elite.sh <update|noupdate> <toolchain> <exp>



# ------
# Colors
# ------
GREEN="\033[01;32m"
RESTORE="\033[0m"



# ----------
# Parameters
# ----------
# Parameter 1: Merge in new changes or not
# Parameter 2: Toolchain to compile with
# Parameter 3: Experimental build (leave off if you want a release build)
FETCHUPSTREAM=${1}
TOOLCHAIN=${2}
# Define EXPERIMENTAL if the third parameter exists
if [[ -n ${3} ]]
then
   EXPERIMENTAL=${3}
fi



# ---------
# Variables
# ---------
# SOURCEDIR: Path to build your kernel
# AKDIR: Directory for the AnyKernel updater
# UPLOADDIR: Upload directory
SOURCEDIR=${HOME}/Kernels/Elite
ZIMAGEDIR=${SOURCEDIR}/arch/arm64/boot
AKDIR=${SOURCEDIR}/packagesm
# If EXPERIMENTAL exists, we are doing an experimental build; change branch and upload location
if [[ -n ${EXPERIMENTAL} ]]
then
   UPLOADDIR=${HOME}/shared/Kernels/angler/Elite/Experimental
   BRANCH=Elite-exp
else
   UPLOADDIR=${HOME}/shared/Kernels/angler/Elite
   BRANCH=Elite-merged
fi

# Toolchain location and info
if [ "${TOOLCHAIN}" == "linaro" ]
then
   TOOLCHAIN_VER="Linaro4.9"
   TOOLCHAIN_DIR=Toolchains/Linaro-4.9
elif [ "${TOOLCHAIN}" == "aosp" ]
then
   TOOLCHAIN_VER="AOSP4.9"
   TOOLCHAIN_DIR=Toolchains/AOSP
elif [ "${TOOLCHAIN}" == "uber4" ]
then
   TOOLCHAIN_VER="UBER4.9"
   TOOLCHAIN_DIR=Toolchains/UBER4
elif [ "${TOOLCHAIN}" == "uber5" ]
then
   TOOLCHAIN_VER="UBER5.4"
   TOOLCHAIN_DIR=Toolchains/UBER5
elif [ "${TOOLCHAIN}" == "uber6" ]
then
   TOOLCHAIN_VER="UBER6.1"
   TOOLCHAIN_DIR=Toolchains/UBER6
elif [ "${TOOLCHAIN}" == "uber7" ]
then
   TOOLCHAIN_VER="UBER7.0"
   TOOLCHAIN_DIR=Toolchains/UBER7
fi

export CROSS_COMPILE="${HOME}/Kernels/${TOOLCHAIN_DIR}/bin/aarch64-linux-android-"
export ARCH=arm64
export SUBARCH=arm64
export LOCALVERSION="-Elite-Angler-${TOOLCHAIN_VER}"
# Export the COMPILE_LOG variable for other files to use (I currently handle this via .bashrc)
# export LOGDIR=${HOME}/Logs
# export COMPILE_LOG=${LOGDIR}/compile_log_`date +%m_%d_%y`.log



# Clear the terminal
clear



# Start tracking time and date to add to zip
START=$(date +%s)
today=$(date +"%m_%d_%Y")



# Change to source directory to start
cd ${SOURCEDIR}



# Show Elite logo to start
echo -e ${GREEN}
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
echo -e ${GREEN}
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
   echo -e ${GREEN}
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
ZIPNAME=${KERNELNAME}-${today}-${TOOLCHAIN_VER}



# remove backup files
find ./ -name '*~' | xargs -r rm



# make kernel
echo -e ""
echo -e ${GREEN}
echo -e "-------------"
echo -e "MAKING KERNEL"
echo -e "-------------"
echo -e ${RESTORE}
echo -e ""

make 'angler_defconfig'
make -j$(grep -c ^processor /proc/cpuinfo)

done



if [ `ls ${ZIMAGEDIR}/Image.gz-dtb 2>/dev/null | wc -l` != "0" ]
then
   BUILD_SUCCESS_STRING="BUILD SUCCESSFUL"


   # Grab zImage-dtb
   echo -e ${GREEN}
   echo -e ""
   echo -e "-----------------------"
   echo -e "Collecting Image.gz-dtb"
   echo -e "-----------------------"
   echo -e ${RESTORE}

   cp ${ZIMAGEDIR}/Image.gz-dtb out/${KERNELNAME}/Image.gz-dtb



   # Build Zip
   echo -e ${GREEN}
   echo -e "----------"
   echo -e "MAKING ZIP" | tr [a-z] [A-Z]
   echo -e "----------"
   echo -e ${RESTORE}

   cd ${SOURCEDIR}/out/${KERNELNAME}/
   7z a -tzip -mx5 "${ZIPNAME}.zip"



   # Remove the previous zip and move the new zip into the upload directory
   echo -e ""
   echo -e ${GREEN}
   echo -e "----------"
   echo -e "MOVING ZIP" | tr [a-z] [A-Z]
   echo -e "----------"
   echo -e ${RESTORE}

   rm ${UPLOADDIR}/Elite_*${TOOLCHAIN_VER}.zip
   mv ${ZIPNAME}.zip ${UPLOADDIR}



   # Upload it
   echo -e ${GREEN}
   echo -e "-------------"
   echo -e "UPLOADING ZIP" | tr [a-z] [A-Z]
   echo -e "-------------"
   echo -e ${RESTORE}
   echo -e ""

   . ${HOME}/upload.sh

else
   BUILD_SUCCESS_STRING="BUILD FAILED"

fi


# Remove the out directory
rm -rf ${SOURCEDIR}/out



# Go to the home directory
cd ${HOME}



# Success! Stop tracking time
echo -e ""
echo -e ${GREEN}
echo "--------------------"
echo "SCRIPT COMPLETED IN:"
echo "--------------------"

END=$(date +%s)
DIFF=$((${END} - ${START}))

echo -e "${BUILD_SUCCESS_STRING}!"
echo -e "TIME: $((${DIFF} / 60)) MINUTES AND $((${DIFF} % 60)) SECONDS"

echo -e ${RESTORE}

# Add line to compile log
echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${TOOLCHAIN_VER}" >> ${COMPILE_LOG}
echo -e "${BUILD_SUCCESS_STRING} IN $((${DIFF} / 60)) MINUTES AND $((${DIFF} % 60)) SECONDS\n" >> ${COMPILE_LOG}

echo -e "\a"
