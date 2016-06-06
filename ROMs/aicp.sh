#!/bin/bash

# -----
# Usage
# -----
# $ . aicp.sh <device> <sync|nosync>



# --------
# Examples
# --------
# $ . aicp.sh angler sync
# $ . aicp.sh angler nosync



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
SOURCEDIR=${HOME}/ROMs/AICP
OUTDIR=${SOURCEDIR}/out/target/product/${DEVICE}
UPLOADDIR=${HOME}/shared/ROMs/AICP/${DEVICE}



# ------
# Colors
# ------
BLDBLUE="\033[1m""\033[36m"
RST="\033[0m"



# Export the COMPILE_LOG variable for other files to use (I currently handle this via .bashrc)
# export LOGDIR=${HOME}/Logs
# export COMPILE_LOG=${LOGDIR}/compile_log_`date +%m_%d_%y`.log



# Clear the terminal
clear



# Start tracking time
echo -e ${BLDBLUE}
echo -e "---------------------------------------"
echo -e "SCRIPT STARTING AT $(date +%D\ %r)"
echo -e "---------------------------------------"
echo -e ${RST}

START=$(date +%s)



# Change to the source directory
echo -e ${BLDBLUE}
echo -e "------------------------------------"
echo -e "MOVING TO ${SOURCEDIR}"
echo -e "------------------------------------"
echo -e ${RST}

cd ${SOURCEDIR}



# Sync the repo if requested
if [ "${SYNC}" == "sync" ]
then
   echo -e ${BLDBLUE}
   echo -e "----------------------"
   echo -e "SYNCING LATEST SOURCES"
   echo -e "----------------------"
   echo -e ${RST}
   echo -e ""

   repo sync --force-sync
fi



# Setup the build environment
echo -e ${BLDBLUE}
echo -e "----------------------------"
echo -e "SETTING UP BUILD ENVIRONMENT"
echo -e "----------------------------"
echo -e ${RST}
echo -e ""

. build/envsetup.sh



# Prepare device
echo -e ${BLDBLUE}
echo -e "----------------"
echo -e "PREPARING DEVICE"
echo -e "----------------"
echo -e ${RST}
echo -e ""

breakfast ${DEVICE}



# Clean up
echo -e ${BLDBLUE}
echo -e "--------------------------------------------"
echo -e "CLEANING UP ${SOURCEDIR}/out"
echo -e "--------------------------------------------"
echo -e ${RST}
echo -e ""

make clean
make clobber



# Start building
echo -e ${BLDBLUE}
echo -e "---------------"
echo -e "MAKING ZIP FILE"
echo -e "---------------"
echo -e ${RST}
echo -e ""

time mka bacon



# If the above was successful
if [ `ls ${OUTDIR}/aicp_${DEVICE}_mm*.zip 2>/dev/null | wc -l` != "0" ]
then
   BUILD_SUCCESS_STRING="BUILD SUCCESSFUL"



   # Remove exisiting files in UPLOADDIR
   echo -e ""
   echo -e ${BLDBLUE}
   echo -e "-------------------------"
   echo -e "CLEANING UPLOAD DIRECTORY"
   echo -e "-------------------------"
   echo -e ${RST}

   rm ${UPLOADDIR}/*_${DEVICE}_*.zip
   rm ${UPLOADDIR}/*_${DEVICE}_*.zip.md5sum



   # Copy new files to UPLOADDIR
   echo -e ${BLDBLUE}
   echo -e "--------------------------------"
   echo -e "MOVING FILES TO UPLOAD DIRECTORY"
   echo -e "--------------------------------"
   echo -e ${RST}

   mv ${OUTDIR}/aicp_${DEVICE}_mm*.zip ${UPLOADDIR}
   mv ${OUTDIR}/aicp_${DEVICE}_mm*.zip.md5sum ${UPLOADDIR}



   # Upload the files
   echo -e ${BLDBLUE}
   echo -e "---------------"
   echo -e    "UPLOADING FILES"
   echo -e "---------------"
   echo -e ${RST}
   echo -e ""

   . ${HOME}/upload.sh



   # Clean up out directory to free up space
   echo -e ""
   echo -e ${BLDBLUE}
   echo -e "--------------------------------------------"
   echo -e "CLEANING UP ${SOURCEDIR}/out"
   echo -e "--------------------------------------------"
   echo -e ${RST}
   echo -e ""

   make clean
   make clobber



   # Go back home
   echo -e ${BLDBLUE}
   echo -e "----------"
   echo -e "GOING HOME"
   echo -e "----------"
   echo -e ${RST}

   cd ${HOME}

# If the build failed, add a variable
else
   BUILD_SUCCESS_STRING="BUILD FAILED"

fi



# Stop tracking time
END=$(date +%s)
echo -e ${BLDBLUE}
echo -e "-------------------------------------"
echo -e "SCRIPT ENDING AT $(date +%D\ %r)"
echo -e ""
echo -e "${BUILD_SUCCESS_STRING}!"
echo -e "TIME: $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')"
echo -e "-------------------------------------"
echo -e ${RST}

# Add line to compile log
echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${DEVICE}" >> ${COMPILE_LOG}
echo -e "${BUILD_SUCCESS_STRING} IN $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')\n" >> ${COMPILE_LOG}

echo -e "\a"
