#!/bin/bash


# Usage:
# $ source update-su.sh (build-img)


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


# Superuser folders
SU_SOURCE_FOLDER=${HOME}/Superuser/Superuser
SU_BINARY_FOLDER=${SU_SOURCE_FOLDER}/libs/armeabi


# PureNexus repos
PN_SOURCE=${HOME}/ROMs/PN
DEVICE_TREE=device/huawei/angler
SYSTEM_CORE=system/core
SEPOLICY=system/sepolicy

# Where to copy the image if requested
IMG_MOVE=${HOME}/Completed/Images/SU
IMG=su-angler-$( TZ=MST date +%m%d%Y ).img


# Clear terminal window
clear


# Start tracking time for script duration
START=$( TZ=MST date +%s )


# If the script is being called to build a boot image, we need to sync the PN repo before making changes; otherwise, it will be called before running this script
if [[ "${1}" == "build-img" ]]; then
   echoText "UPDATING SOURCE"

   cd ${PN_SOURCE}
   time repo sync --force-sync -j$(grep -c ^processor /proc/cpuinfo)
fi


# Build the su binary straight from phh's source
echoText "BUILDING SU"

cd ${SU_SOURCE_FOLDER}
git clean -fxd
git reset --hard origin/master
git pull
ndk-build clean
ndk-build -B


# Copy the su binary to our device tree folder
echoText "MOVING SU"

cp -v ${SU_BINARY_FOLDER}/su ${PN_SOURCE}/${DEVICE_TREE}


# Apply the necessary commits to support the su binary (available on my Github)
echoText "APPLYING COMMITS"

cd ${PN_SOURCE}/${DEVICE_TREE}
git fetch https://github.com/nathanchance/device_huawei_angler_su android-7.0.0_r1
git cherry-pick ca405f125ca00c038fe4b16eb3964fbc9193218c

cd ${PN_SOURCE}/${SEPOLICY}
git fetch https://github.com/nathanchance/system_sepolicy_su android-7.0.0_r1
git cherry-pick 9431542b89df6860814096a81d3e21603c7c7d81

cd ${PN_SOURCE}/${SYSTEM_CORE}
git fetch https://github.com/nathanchance/system_core_su n
git cherry-pick 5b22c30457c4723c7203a4c30072e051867d9762


# If the script is being called to build a boot image, do so
if [[ "${1}" == "build-img" ]]; then
   # Move into our source directory
   cd ${PN_SOURCE}

   # Setup the environment
   echoText "PREPARING ENVIRONMENT"

   . build/envsetup.sh
   lunch nexus_angler-userdebug

   # Make the boot image
   echoText "MAKING BOOT.IMG"

   mka bootimage

   # If the IMG_MOVE folder doesn't exist, make it; otherwise, clean it
   if [[ ! -d ${IMG_MOVE} ]]; then
      mkdir -p ${IMG_MOVE}
   else
      rm -rf ${IMG_MOVE}/su-angler*.img
   fi

   # Copy the completed image if it exists
   if [[ -f ${PN_SOURCE}/out/target/product/angler/boot.img ]]; then
      BUILD_RESULT_STRING="BUILD SUCCESSFUL"

      echoText "MOVING BOOT.IMG"
      cp -v ${PN_SOURCE}/out/target/product/angler/boot.img ${IMG_MOVE}/${IMG}

      echoText "CLEANING OUT FOLDER"
      mka clobber && rm -vrf ${PN_SOURCE}/${DEVICE_TREE}/su
   else
      BUILD_RESULT_STRING="BUILD FAILED"
   fi

   # Stop tracking time
   END=$( TZ=MST date +%s )


   # Print out result of script and time it took to compile
   echoText "${BUILD_RESULT_STRING}"
   if [[ "${BUILD_RESULT_STRING}" == "BUILD SUCCESSFUL" ]]; then
      echo -e ${RED}"IMAGE: ${IMG_MOVE}/${IMG}"
      echo -e "SIZE: $( du -h ${IMG_MOVE}/${IMG} | awk '{print $1}' )"${RESTORE}
   fi
   echo -e ${RED}"DURATION: $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )"${RESTORE}; newLine


   # Go home
   cd ${HOME}
fi
