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
if [ "${1}" == "me" ]
then
   TYPE=banks
   ZIPMOVE=${HOME}/shared/.me
else
   TYPE=${1}
   ZIPMOVE=${HOME}/shared/GApps
fi


# ---------
# Variables
# ---------
ANDROIDDIR=${HOME}
if [ "${TYPE}" == "banks" ]
then
    SOURCEDIR=${ANDROIDDIR}/GApps/Banks
    ZIPBEG=banks
    BRANCH=m
elif [ "${TYPE}" == "pn" ]
then
    SOURCEDIR=${ANDROIDDIR}/GApps/PN
    ZIPBEG=PureNexus
    BRANCH=mm2
fi
# Export the COMPILE_LOG variable for other files to use (I currently handle this via .bashrc)
# export LOGDIR=${ANDROID_DIR}/Logs
# export COMPILE_LOG=${LOGDIR}/compile_log_`date +%m_%d_%y`.log



# Clear the terminal
clear



# Start tracking time
START=$(date +%s)



# Go into repo folder
cd ${SOURCEDIR}



# Clean up repo
git reset --hard origin/${BRANCH}
git clean -f -d -x



# Get new changes
git pull



# Make GApps
. mkgapps.sh



# If the above was successful
if [ `ls ${SOURCEDIR}/out/${ZIPBEG}*.zip 2>/dev/null | wc -l` != "0" ]
then
   BUILD_RESULT_STRING="BUILD SUCCESSFUL"


   # Remove current GApps and move the new ones in their place
   rm ${ZIPMOVE}/${ZIPBEG}*.zip
   mv ${SOURCEDIR}/out/${ZIPBEG}*.zip ${ZIPMOVE}



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
echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${TYPE}" >> ${COMPILE_LOG}
echo -e "${BUILD_RESULT_STRING} IN $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')\n" >> ${COMPILE_LOG}

echo -e "\a"
