#!/bin/bash

# -----
# Usage
# -----
# $ . du.sh <device> <sync|nosync> <person>



# --------
# Examples
# --------
# $ . du.sh angler sync me
# $ . du.sh angler nosync bre



# ----------
# Parameters
# ----------
# Parameter 1: device (eg. angler, bullhead, shamu)
# Parameter 2: sync or nosync (decides whether or not to run repo sync)
# Parameter 3: person (if custom build tag and location are needed)
DEVICE=${1}
SYNC=${2}
# If the third parameter exists
if [[ -n ${3} ]]
then
   PERSON=${3}
fi



# ---------
# Variables
# ---------
SOURCEDIR=${HOME}/ROMs/DU
OUTDIR=${SOURCEDIR}/out/target/product/${DEVICE}

# If PERSON does not exist
if [[ -z ${PERSON} ]]
then
   export DU_BUILD_TYPE=CHANCELLOR
   UPLOADDIR=${HOME}/shared/ROMs/"Dirty Unicorns"/${DEVICE}
# If PERSON does exist
else
   UPLOADDIR=${HOME}/shared/ROMs/.special/.${PERSON}

   # Add custom build tag
   if [ "${PERSON}" == "alcolawl" ]
   then
     export DU_BUILD_TYPE=ALCOLAWL
   elif [ "${PERSON}" == "bre" ]
   then
      export DU_BUILD_TYPE=BREYANA
   elif [ "${PERSON}" == "drew" ]
   then
      export DU_BUILD_TYPE=DREW
   elif [ "${PERSON}" == "hmhb" ]
   then
      export DU_BUILD_TYPE=DIRTY-DEEDS
   elif [ "${PERSON}" == "jdizzle" ]
   then
      export DU_BUILD_TYPE=NINJA
   fi
fi



# ------
# Colors
# ------
BLDRED="\033[1m""\033[31m"
RST="\033[0m"



# Export the COMPILE_LOG variable for other files to use (I currently handle this via .bashrc)
# export LOGDIR=${HOME}/Logs
# export COMPILE_LOG=${LOGDIR}/compile_log_`date +%m_%d_%y`.log



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



# If the above was successful
if [ `ls ${OUTDIR}/DU_${DEVICE}_*.zip 2>/dev/null | wc -l` != "0" ]
then
   BUILD_SUCCESS_STRING="BUILD SUCCESSFUL"



   # Remove exisiting files in UPLOADDIR
   echo -e ""
   echo -e ${BLDRED}
   echo -e "-------------------------"
   echo -e "CLEANING UPLOAD DIRECTORY"
   echo -e "-------------------------"
   echo -e ${RST}

   rm "${UPLOADDIR}"/*_${DEVICE}_*.zip
   rm "${UPLOADDIR}"/*_${DEVICE}_*.zip.md5sum



   # Copy new files to UPLOADDIR
   echo -e ${BLDRED}
   echo -e "--------------------------------"
   echo -e "MOVING FILES TO UPLOAD DIRECTORY"
   echo -e "--------------------------------"
   echo -e ${RST}

   mv ${OUTDIR}/DU_${DEVICE}_*.zip "${UPLOADDIR}"
   mv ${OUTDIR}/DU_${DEVICE}_*.zip.md5sum "${UPLOADDIR}"



   # Upload the files
   echo -e ${BLDRED}
   echo -e "---------------"
   echo -e "UPLOADING FILES"
   echo -e "---------------"
   echo -e ${RST}
   echo -e ""

   . ${HOME}/upload.sh



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

   cd ${HOME}

# If the build failed, add a variable
else
   BUILD_SUCCESS_STRING="BUILD FAILED"

fi



# Stop tracking time
END=$(date +%s)
echo -e ${BLDRED}
echo -e "-------------------------------------"
echo -e "SCRIPT ENDING AT $(date +%D\ %r)"
echo -e ""
echo -e "${BUILD_SUCCESS_STRING}!"
echo -e "TIME: $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')"
echo -e "-------------------------------------"
echo -e ${RST}

# Add line to compile log
if [[ -n ${PERSON} ]]
then
   export DU_BUILD_TYPE=CHANCELLOR
   echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${PERSON}" >> ${COMPILE_LOG}
else
   echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${DEVICE}" >> ${COMPILE_LOG}
fi
echo -e "${BUILD_SUCCESS_STRING} IN $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')\n" >> ${COMPILE_LOG}

echo -e "\a"
