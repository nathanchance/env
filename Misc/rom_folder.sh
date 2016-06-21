#!/bin/bash

# -----
# Usage
# -----
# $ . rom_folder.sh <rom> <sync|nosync>



# ----------
# Parameters
# ----------
# Parameter 1: the ROM, possible values include aicp|aosip|du|pn|screwd|temasek
# Parameter 2: whether or not to sync the repo right away
ROM=${1}
SYNC=${2}



# ------
# Colors
# ------
BLDRED="\033[1m""\033[31m"
BLDBLUE="\033[1m""\033[36m"
RST="\033[0m"



# Parent directory of source
ANDROID_DIR=${HOME}
ROM_DIR=${ANDROID_DIR}/ROMs



# Define the name of the source directory as well as the repo URL and the repo branch to sync
if [ "${ROM}" == "aicp" ]
then
   SOURCE_DIR=${ROM_DIR}/AICP
   REPO_URL=https://github.com/AICP/platform_manifest.git
   REPO_BRANCH=mm6.0
elif [ "${ROM}" == "aosip" ]
then
   SOURCE_DIR=${ROM_DIR}/AOSiP
   REPO_URL=https://github.com/AOSIP/platform_manifest.git
   REPO_BRANCH=mm6.0
elif [ "${ROM}" == "du" ]
then
   SOURCE_DIR=${ROM_DIR}/DU
   REPO_URL=http://github.com/DirtyUnicorns/android_manifest.git
   REPO_BRANCH=m
elif [ "${ROM}" == "pn" ]
then
   SOURCE_DIR=${ROM_DIR}/PN
   REPO_URL=https://github.com/PureNexusProject/manifest.git
   REPO_BRANCH=mm2
elif [ "${ROM}" == "pnmod" ]
then
   SOURCE_DIR=${ROM_DIR}/PN-Mod
   REPO_URL=https://github.com/ezio84/pnmod-manifest.git
   REPO_BRANCH=mm2
elif [ "${ROM}" == "screwd" ]
then
   SOURCE_DIR=${ROM_DIR}/Screwd
   REPO_URL=https://github.com/ScrewdAOSP/platform_manifest.git
   REPO_BRANCH=m
elif [ "${ROM}" == "temasek" ]
then
   SOURCE_DIR=${ROM_DIR}/Temasek
   REPO_URL=https://github.com/temasek/android.git
   REPO_BRANCH=cm-13.0
fi



# Start tracking time
echo -e ${BLDRED}
echo -e "---------------------------------------"
echo -e "SCRIPT STARTING AT $(date +%D\ %r)"
echo -e "---------------------------------------"
echo -e ${RST}

START=$(date +%s)



# Remove the previous directory and create a new one
echo -e ${BLDRED}
echo -e "----------------------------"
echo -e "REMOVING AND CREATING FOLDER"
echo -e "----------------------------"

rm -rf ${SOURCE_DIR}
mkdir ${SOURCE_DIR}

echo -e ${BLDBLUE}
echo -e "REMOVED: ${SOURCE_DIR}"
echo -e "CREATED: ${SOURCE_DIR}"
echo -e ${RST}



# Sync the source if requested
if [ "$SYNC" == "sync" ]
then
   echo -e ${BLDRED}
   echo -e "------------"
   echo -e "SYNCING REPO"
   echo -e "------------"
   echo -e ${BLDBLUE}
   echo -e "URL: ${REPO_URL}"
   echo -e "BRANCH: ${REPO_BRANCH}"
   echo -e ${RST}

   # run the repo command
   cd ${SOURCE_DIR}
   repo init -u ${REPO_URL} -b ${REPO_BRANCH}

   if [ "${ROM}" == "rr" ]
   then
      mkdir ${SOURCE_DIR}/.repo/local_manifests
      cp -v ${ROM_DIR}/Manifests/rr_shamu.xml ${SOURCE_DIR}/.repo/local_manifests
   elif [ "${ROM}" == "pnmod" ]
      mkdir ${SOURCE_DIR}/.repo/local_manifests
      cp -v ${ROM_DIR}/Manifests/pn-mod.xml ${SOURCE_DIR}/.repo/local_manifests
   fi

  repo sync --force-sync



   echo -e ${BLDRED}
   echo -e "--------------------"
   echo -e "SYNCING DEPENDENCIES"
   echo -e "--------------------"
   echo -e ${RST}

   # Sync dependencies
   . build/envsetup.sh

   if [ "${ROM}" == "screwd" ]
   then
      lunch screwd_angler-userdebug
      lunch screwd_bullhead-userdebug
      lunch screwd_hammerhead-userdebug
      lunch screwd_shamu-userdebug
   else
      breakfast angler
      breakfast bullhead
      breakfast hammerhead
      breakfast shamu
    fi
fi



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
