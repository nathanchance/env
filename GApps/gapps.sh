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
TYPE=${1}



# ---------
# Variables
# ---------
if [ "${TYPE}" == "banks" ]
then
    SOURCEDIR=~/GApps/Banks
    ZIPBEG=BaNkS
elif [ "${TYPE}" == "pn" ]
then
    SOURCEDIR=~/GApps/PN
    ZIPBEG=PureNexus
fi
UPLOADDIR=~/shared/GApps



# Clear the terminal
clear



# Go into repo folder
cd ${SOURCEDIR}



# Clean unsaved changes and get new changes
git reset --hard
git clean -f -d
git pull



# Make GApps
. mkgapps.sh



# Remove current GApps and move the new ones in their place
rm ${UPLOADDIR}/${ZIPBEG}*.zip
mv ${SOURCEDIR}/out/${ZIPBEG}*.zip ${UPLOADDIR}



# Upload them
. ~/upload.sh



# Go home and we're done!
cd ${HOME}

echo -e ${BLDGREEN}
echo -e "---------------------------------"
echo -e "COMPILATION AND UPLOAD SUCCESSFUL"
echo -e "---------------------------------"
echo -e ${RST}

echo -e "\a"
