#!/bin/bash

# -----
# Usage
# -----
# $ . screwd.sh <device> <sync|nosync>



# --------
# Examples
# --------
# $ . screwd.sh angler sync
# $ . screwd.sh angler nosync



# ----------
# Parameters
# ----------
# Parameter 1: device (eg. angler, bullhead, shamu)
# Parameter 2: sync or nosync (decides whether or not to run repo sync)
DEVICE=$1
SYNC=$2



# ---------
# Variables
# ---------
SOURCEDIR=${HOME}/ROMs/Screwd
OUTDIR=${SOURCEDIR}/out/target/product/${DEVICE}
UPLOADDIR=${HOME}/shared/ROMs/"Screw'd"/${DEVICE}
LOGDIR=${HOME}/Logs



# ------
# Colors
# ------
BLDMAG="\033[1m""\033[35m"
RST="\033[0m"



# Export the COMPILE_LOG variable for other files to use
export COMPILE_LOG=compile_log_`date +%m_%d_%y`.log



# Clear the terminal
clear



# Start tracking time
echo -e ${BLDMAG}
echo -e "---------------------------------------"
echo -e "SCRIPT STARTING AT $(date +%D\ %r)"
echo -e "---------------------------------------"
echo -e ${RST}

START=$(date +%s)



# Change to the source directory
echo -e ${BLDMAG}
echo -e "----------------------------------------"
echo -e "MOVING TO ${SOURCEDIR}"
echo -e "----------------------------------------"
echo -e ${RST}

cd ${SOURCEDIR}



# Sync the repo if requested
if [ "${SYNC}" == "sync" ]
then
   echo -e ${BLDMAG}
   echo -e "----------------------"
   echo -e "SYNCING LATEST SOURCES"
   echo -e "----------------------"
   echo -e ${RST}
   echo -e ""

   repo sync --force-sync
fi



# Setup the build environment
echo -e ${BLDMAG}
echo -e "----------------------------"
echo -e "SETTING UP BUILD ENVIRONMENT"
echo -e "----------------------------"
echo -e ${RST}
echo -e ""

. build/envsetup.sh



# Prepare device
echo -e ${BLDMAG}
echo -e "----------------"
echo -e "PREPARING DEVICE"
echo -e "----------------"
echo -e ${RST}
echo -e ""

lunch screwd_${DEVICE}-userdebug



# Clean up
echo -e ${BLDMAG}
echo -e "----------------------------------------------"
echo -e "CLEANING UP ${SOURCEDIR}/out"
echo -e "----------------------------------------------"
echo -e ${RST}
echo -e ""

make clean
make clobber



# Start building
echo -e ${BLDMAG}
echo -e "---------------"
echo -e "MAKING ZIP FILE"
echo -e "---------------"
echo -e ${RST}
echo -e ""

time mka bacon



# If the above was successful
if [ `ls ${OUTDIR}/screwd-*${SCREWD_BUILD_TYPE}*.zip 2>/dev/null | wc -l` != "0" ]
then
   BUILD_SUCCESS_STRING="BUILD SUCCESSFUL!"



   # Remove exisiting files in UPLOADDIR
   echo -e ""
   echo -e ${BLDMAG}
   echo -e "-------------------------"
   echo -e "CLEANING UPLOAD DIRECTORY"
   echo -e "-------------------------"
   echo -e ${RST}

   rm "${UPLOADDIR}"/*-${DEVICE}-*.zip
   rm "${UPLOADDIR}"/*-${DEVICE}-*.zip.md5sum



   # Copy new files to UPLOADDIR
   echo -e ${BLDMAG}
   echo -e "--------------------------------"
   echo -e "MOVING FILES TO UPLOAD DIRECTORY"
   echo -e "--------------------------------"
   echo -e ${RST}

   mv ${OUTDIR}/screwd-*${SCREWD_BUILD_TYPE}*.zip "${UPLOADDIR}"
   mv ${OUTDIR}/screwd-*${SCREWD_BUILD_TYPE}*.zip.md5sum "${UPLOADDIR}"



   # Upload the files
   echo -e ${BLDMAG}
   echo -e "---------------"
   echo -e "UPLOADING FILES"
   echo -e "---------------"
   echo -e ${RST}
   echo -e ""

   . ${HOME}/upload.sh



   # Clean up out directory to free up space
   echo -e ""
   echo -e ${BLDMAG}
   echo -e "----------------------------------------------"
   echo -e "CLEANING UP ${SOURCEDIR}/out"
   echo -e "----------------------------------------------"
   echo -e ${RST}
   echo -e ""

   make clean
   make clobber



   # Go back home
   echo -e ${BLDMAG}
   echo -e "----------"
   echo -e "GOING HOME"
   echo -e "----------"
   echo -e ${RST}

   cd ${HOME}

# If the build failed, add a variable
else
   BUILD_SUCCESS_STRING="BUILD FAILED!"

fi



# Stop tracking time
END=$(date +%s)
echo -e ${BLDMAG}
echo -e "-------------------------------------"
echo -e "SCRIPT ENDING AT $(date +%D\ %r)"
echo -e ""
echo -e "${BUILD_SUCCESS_STRING}"
echo -e "TIME: $(echo $((${END}-${START})) | awk '{print int($1/60)"mins "int($1%60)"secs"}')"
echo -e "-------------------------------------"
echo -e ${RST}

# Add line to compile log
echo -e "`date +%H:%M:%S`: \n${BASH_SOURCE} ${BUILD_SUCCESS_STRING}\n" >> ${LOGDIR}/${COMPILE_LOG}
echo -e "$(echo $((${END}-${START})) | awk '{print int($1/60)"mins "int($1%60)"secs"}')\n" >> ${LOGDIR}/${COMPILE_LOG}

echo -e "\a"
