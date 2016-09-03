#!/bin/bash

# -----
# Usage
# -----
# $ . gapps.sh <banks|pn>



# ---------
# Functions
# ---------
# Prints a formatted header; used for outlining what the script is doing to the user
function echoText() {
   RED="\033[01;31m"
   RST="\033[0m"

   echo -e ${RED}
   echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
   echo -e "==  ${1}  =="
   echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
   echo -e ${RST}
}

# Creates a new line
function newLine() {
   echo -e ""
}



# ----------
# Parameters
# ----------
# Parameter 1: Which GApps to compile? (currently Banks or Pure Nexus Dynamic GApps)

# Unassign personal and success flags
PERSONAL=false
SUCCESS=false

if [[ "${1}" == "me" ]]; then
   PERSONAL=true
   TYPE=banks
   ZIP_MOVE=${HOME}/Completed/Zips/Me
else
   TYPE=${1}
   ZIP_MOVE=${HOME}/Completed/Zips/GApps
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
    BRANCH=m
fi
# Export the LOG variable for other files to use (I currently handle this via .bashrc)
# export LOG_DIR=${ANDROID_DIR}/Logs
# export LOG=${LOG_DIR}/compile_log_$( TZ=MST date +%m_%d_%y ).log



# Clear the terminal
clear



# Start tracking time
START=$( TZ=MST date +%s )



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
   SUCCESS=true

   # If ZIP_MOVE doesn't exist, make it; otherwise, clean it
   if [[ ! -d ${ZIP_MOVE} ]]; then
      mkdir -p ${ZIP_MOVE}
   else
      # Remove current GApps and move the new ones in their place
      if [[ "${TYPE}" == "banks" && ${PERSONAL} = false ]]; then
         rm -rf ${HOME}/Zips/Me/${ZIP_BEG}*.zip
      fi
      rm -rf ${ZIP_MOVE}/${ZIP_BEG}*.zip
   fi

   if [[ "${TYPE}" == "banks" && ${PERSONAL} = false ]]; then
      cp -v ${SOURCE_DIR}/out/${ZIP_BEG}*.zip ${HOME}/Zips/Me
   fi
   mv -v ${SOURCE_DIR}/out/${ZIP_BEG}*.zip ${ZIP_MOVE}



# If the build failed, add a variable
else
   BUILD_RESULT_STRING="BUILD FAILED"
   SUCCESS=false

fi



# Stop tracking time
END=$( TZ=MST date +%s )



# Go home and we're done!
cd ${HOME}



# Stop tracking time
END=$( TZ=MST date +%s )
newLine; echoText "${BUILD_RESULT_STRING}!"

# Print the zip location and its size if the script was successful
if [[ ${SUCCESS} = true ]]; then
   echo -e ${RED}"ZIP: $( ls ${ZIP_MOVE}/${ZIP_BEG}*.zip )"
   echo -e "SIZE: $( du -h ${ZIP_MOVE}/${ZIP_BEG}*.zip | awk '{print $1}' )"${RST}
fi
# Print the time the script finished and how long the script ran for regardless of success
echo -e ${RED}"TIME FINISHED: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
echo -e ${RED}"DURATION: $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )"${RST}; newLine

# Add line to compile log
echo -e "$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${TYPE}" >> ${LOG}
echo -e "${BUILD_RESULT_STRING} IN $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')\n" >> ${LOG}

echo -e "\a"
