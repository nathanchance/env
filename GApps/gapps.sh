#!/bin/bash

# -----
# Usage
# -----
# $ . gapps.sh <banks|pn>



# ------
# Colors
# ------
BLDGREEN="\033[1m""\033[32m"
RST="\033[0m"



# ----------
# Parameters
# ----------
# Parameter 1: Which GApps to compile? (currently Banks or Pure Nexus Dynamic GApps)

# Unassign personal flag
PERSONAL=false

if [[ "${1}" == "me" ]]; then
   PERSONAL=true
   TYPE=banks
   ZIP_MOVE=${HOME}/shared/.me
else
   TYPE=${1}
   ZIP_MOVE=${HOME}/shared/GApps
fi


# ---------
# Variables
# ---------
ANDROID_DIR=${HOME}
if [[ "${TYPE}" == "banks" ]]; then
    SOURCE_DIR=${ANDROID_DIR}/GApps/Banks
    ZIP_BEG=banks
    BRANCH=m
elif [[ "${TYPE}" == "pn" ]]; then
    SOURCE_DIR=${ANDROID_DIR}/GApps/PN
    ZIP_BEG=PureNexus
    BRANCH=mm2
fi
# Export the LOG variable for other files to use (I currently handle this via .bashrc)
# export LOG_DIR=${ANDROID_DIR}/Logs
# export LOG=${LOG_DIR}/compile_log_`date +%m_%d_%y`.log



# Clear the terminal
clear



# Start tracking time
START=$(date +%s)



# Go into repo folder
cd ${SOURCE_DIR}



# Clean up repo
git reset --hard origin/${BRANCH}
git clean -f -d -x



# Get new changes
git pull



# Make GApps
. mkgapps.sh



# If the above was successful
if [[ `ls ${SOURCE_DIR}/out/${ZIP_BEG}*.zip 2>/dev/null | wc -l` != "0" ]]; then
   BUILD_RESULT_STRING="BUILD SUCCESSFUL"



   # Remove current GApps and move the new ones in their place
   if [[ "${TYPE}" == "banks" && ${PERSONAL} = false ]]; then
      rm -rf ${HOME}/shared/.me/${ZIP_BEG}*.zip
   fi
   rm -rf ${ZIP_MOVE}/${ZIP_BEG}*.zip

   if [[ "${TYPE}" == "banks" && ${PERSONAL} = false ]]; then
      cp -v ${SOURCE_DIR}/out/${ZIP_BEG}*.zip ${HOME}/shared/.me
   fi
   mv -v ${SOURCE_DIR}/out/${ZIP_BEG}*.zip ${ZIP_MOVE}



# If the build failed, add a variable
else
   BUILD_RESULT_STRING="BUILD FAILED"

fi



# Upload them
. ~/upload.sh



# Stop tracking time
END=$(date +%s)



# Go home and we're done!
cd ${HOME}



echo -e ${BLDGREEN}
echo -e "-------------------------------------"
echo -e "SCRIPT ENDING AT $(date +%D\ %r)"
echo -e ""
echo -e "${BUILD_RESULT_STRING}!"
echo -e "TIME: $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')"
echo -e "-------------------------------------"
echo -e ${RST}

# Add line to compile log
echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${TYPE}" >> ${LOG}
echo -e "${BUILD_RESULT_STRING} IN $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')\n" >> ${LOG}

echo -e "\a"
