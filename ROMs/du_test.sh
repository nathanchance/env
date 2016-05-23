#!/bin/bash

# -----
# Usage
# -----
# $ . du_test.sh <device> <sync|nosync> <remove|noremove> <DU_BUILD_TYPE>



# --------
# Examples
# --------
# $ . du_test.sh angler sync noremove NICK
# $ . du_test.sh angler nosync remove NINJA



# ----------
# Parameters
# ----------
# Parameter 1: device (eg. angler, bullhead, shamu)
# Parameter 2: sync or nosync (decides whether or not to run repo sync)
# Parameter 3: remove or noremove (decides whether or not to remove the already existing zips)
# Parameter 4: the custom DU_BUILD_TYPE
DEVICE=${1}
SYNC=${2}
DELPREVZIPS=${3}
DUBT=${4}



# ---------
# Variables
# ---------
SOURCEDIR=~/ROMs/DU
OUTDIR=${SOURCEDIR}/out/target/product/${DEVICE}
UPLOADDIR=~/shared/ROMs/.special/.tests



# ------
# Colors
# ------
BLDRED="\033[1m""\033[31m"
RST="\033[0m"



# Special DU build type
export DU_BUILD_TYPE=${DUBT}
export DU_BUILD_TYPE_CL=${DUBT}



# Clear the terminal
clear



# Start tracking time
echo -e ${BLDRED}
echo -e "---------------------------------------"
echo -e "SCRIPT STARTING AT $(date +%D\ %r)"
echo -e "---------------------------------------"
echo -e ${RST}

START=$(date +%s)



# Change to the source directory
echo -e ${BLDRED}
echo -e "------------------------------------"
echo -e "MOVING TO ${SOURCEDIR}"
echo -e "------------------------------------"
echo -e ${RST}

cd ${SOURCEDIR}



# Sync the repo if requested
if [ "${SYNC}" == "sync" ]
then
   echo -e ${BLDRED}
   echo -e "----------------------"
   echo -e "SYNCING LATEST SOURCES"
   echo -e "----------------------"
   echo -e ${RST}
   echo -e ""

   repo sync --force-sync
fi



# Setup the build environment
echo -e ${BLDRED}
echo -e "----------------------------"
echo -e "SETTING UP BUILD ENVIRONMENT"
echo -e "----------------------------"
echo -e ${RST}
echo -e ""

. build/envsetup.sh



# Prepare device
echo -e ${BLDRED}
echo -e "----------------"
echo -e "PREPARING DEVICE"
echo -e "----------------"
echo -e ${RST}
echo -e ""

breakfast ${DEVICE}



# Clean up
echo -e ${BLDRED}
echo -e "------------------------------------------"
echo -e "CLEANING UP ${SOURCEDIR}/out"
echo -e "------------------------------------------"
echo -e ${RST}
echo -e ""

make clean
make clobber



# Start building
echo -e ${BLDRED}
echo -e "---------------"
echo -e "MAKING ZIP FILE"
echo -e "---------------"
echo -e ${RST}
echo -e ""

time mka bacon



echo -e ""
# Remove exisiting files in UPLOADDIR
if [ "${DELPREVZIPS}" == "remove" ]
then
   echo -e ${BLDRED}
   echo -e "-------------------------"
   echo -e "CLEANING UPLOAD DIRECTORY"
   echo -e "-------------------------"
   echo -e ${RST}

   rm ${UPLOADDIR}/*_${DEVICE}_*${DU_BUILD_TYPE}.zip
   rm ${UPLOADDIR}/*_${DEVICE}_*${DU_BUILD_TYPE}.zip.md5sum
fi



# Copy new files to UPLOADDIR
echo -e ${BLDRED}
echo -e "--------------------------------"
echo -e "MOVING FILES TO UPLOAD DIRECTORY"
echo -e "--------------------------------"
echo -e ${RST}

mv ${OUTDIR}/DU_${DEVICE}_*.zip ${UPLOADDIR}
mv ${OUTDIR}/DU_${DEVICE}_*.zip.md5sum ${UPLOADDIR}



# Upload the files
echo -e ${BLDRED}
echo -e "---------------"
echo -e "UPLOADING FILES"
echo -e "---------------"
echo -e ${RST}
echo -e ""

. ~/upload.sh



# Clean up out directory to free up space
echo -e ""
echo -e ${BLDRED}
echo -e "------------------------------------------"
echo -e "CLEANING UP ${SOURCEDIR}/out"
echo -e "------------------------------------------"
echo -e ${RST}
echo -e ""

make clean
make clobber



# Go back home
echo -e ${BLDRED}
echo -e "----------"
echo -e "GOING HOME"
echo -e "----------"
echo -e ${RST}

cd ~/



# Set DU build type back to CHANCELLOR
export DU_BUILD_TYPE=CHANCELLOR



# Stop tracking time
END=$(date +%s)
echo -e ${BLDRED}
echo -e "-------------------------------------"
echo -e "SCRIPT ENDING AT $(date +%D\ %r)"
echo -e ""
echo -e "TIME: $(echo $(($END-$START)) | awk '{print int($1/60)"mins "int($1%60)"secs"}')"
echo -e "-------------------------------------"
echo -e ${RST}
echo -e "\a"
