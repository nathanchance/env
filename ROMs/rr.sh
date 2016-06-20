#!/bin/bash

# -----
# Usage
# -----
# $ . rr.sh <sync|nosync>
# Parameter 1: sync or nosync (decides whether or not to run repo sync)
# There could be a device parameter like the other scripts but I only plan on compiling this ROM for Shamu



# --------
# Examples
# --------
# $ . rr.sh sync
# $ . rr.sh nosync



# ----------
# Parameters
# ----------
DEVICE=shamu
SYNC=${1}



# ---------
# Variables
# ---------
ANDROIDDIR=${HOME}
SOURCEDIR=${ANDROIDDIR}/ROMs/RR
OUTDIR=${SOURCEDIR}/out/target/product/${DEVICE}
ZIPMOVE=${HOME}/shared/ROMs/ResurrectionRemix/${DEVICE}



# ------
# Colors
# ------
BLDGREEN="\033[1m""\033[32m"
RST="\033[0m"



# Export the COMPILE_LOG variable for other files to use (I currently handle this via .bashrc)
# export LOGDIR=${ANDROIDDIR}/Logs
# export COMPILE_LOG=${LOGDIR}/compile_log_`date +%m_%d_%y`.log



# Clear the terminal
clear



# Start tracking time
echo -e ${BLDGREEN}
echo -e "---------------------------------------"
echo -e "SCRIPT STARTING AT $(date +%D\ %r)"
echo -e "---------------------------------------"
echo -e ${RST}

START=$(date +%s)



# Change to the source directory
echo -e ${BLDGREEN}
echo -e "------------------------------------"
echo -e "MOVING TO ${SOURCEDIR}"
echo -e "------------------------------------"
echo -e ${RST}

cd ${SOURCEDIR}



# Sync the repo if requested
if [ "${SYNC}" == "sync" ]
then
   echo -e ${BLDGREEN}
   echo -e "----------------------"
   echo -e "SYNCING LATEST SOURCES"
   echo -e "----------------------"
   echo -e ${RST}
   echo -e ""

   repo sync --force-sync
fi



# I could fork these repos and do the changes in there permanently but I don't want to have to maintains anything extra
echo -e ${BLDGREEN}
echo -e "---------------------------------------"
echo -e "PICKING EXTRA COMMITS AND ADDING KA-MOD"
echo -e "---------------------------------------"
echo -e ${RST}
echo -e ""

# 1. Change DESOLATED to KBUILD_BUILD_HOST and allow kernel to be compiled with UBER 6.1
cd ${SOURCEDIR}/kernel/moto/shamu
git fetch https://github.com/nathanchance/B14CKB1RD_Kernel_N6.git
git cherry-pick 20f83cadace94da9b711ebb53661b1682885888a
# 2. Change from shamu_defconfig to B14CKB1RD_defconfig
cd ${SOURCEDIR}/device/moto/shamu
git fetch https://github.com/nathanchance/android_device_moto_shamu.git
git cherry-pick 0d2c6f3bdfe6e78b9b8036471dd3dcb6945fbb51
# 3. Stop per app overlays from being reset (thanks @bigrushdog)
cd ${SOURCEDIR}/packages/apps/ThemeChooser
git fetch https://github.com/nathanchance/android_packages_apps_ThemeChooser.git
git cherry-pick 1cefd98f7ac5db31754a8f7ee1fd62f3ac897b71
# 4. Add @Yoinx's Kernel Adiutor-Mod instead of the regular Kernel Adiutor (to complement Blackbird)
cd ${SOURCEDIR}/vendor/cm/prebuilt/KernelAdiutor
rm -rf KernelAdiutor.apk
wget https://github.com/yoinx/kernel_adiutor/raw/master/download/app/app-release.apk
mv app-release.apk KernelAdiutor.apk
cd ${SOURCEDIR}
# I want to make sure the picks went through okay
sleep 10



# Setup the build environment
echo -e ${BLDGREEN}
echo -e "----------------------------"
echo -e "SETTING UP BUILD ENVIRONMENT"
echo -e "----------------------------"
echo -e ${RST}
echo -e ""

. build/envsetup.sh



# Prepare device
echo -e ${BLDGREEN}
echo -e "----------------"
echo -e "PREPARING DEVICE"
echo -e "----------------"
echo -e ${RST}
echo -e ""

breakfast ${DEVICE}



# Clean up
echo -e ${BLDGREEN}
echo -e "------------------------------------------"
echo -e "CLEANING UP ${SOURCEDIR}/out"
echo -e "------------------------------------------"
echo -e ${RST}
echo -e ""

make clobber



# Start building
echo -e ${BLDGREEN}
echo -e "---------------"
echo -e "MAKING ZIP FILE"
echo -e "---------------"
echo -e ${RST}
echo -e ""

time mka bacon



# If the above was successful
if [ `ls ${OUTDIR}/ResurrectionRemix*-${DEVICE}.zip 2>/dev/null | wc -l` != "0" ]
then
   BUILD_RESULT_STRING="BUILD SUCCESSFUL"



   # Remove exisiting files in ZIPMOVE
   echo -e ""
   echo -e ${BLDGREEN}
   echo -e "--------------------------"
   echo -e "CLEANING ZIPMOVE DIRECTORY"
   echo -e "--------------------------"
   echo -e ${RST}

   rm "${ZIPMOVE}"/*${DEVICE}*.zip
   rm "${ZIPMOVE}"/*${DEVICE}*.zip.md5sum



   # Copy new files to ZIPMOVE
   echo -e ${BLDGREEN}
   echo -e "---------------------------------"
   echo -e "MOVING FILES TO ZIPMOVE DIRECTORY"
   echo -e "---------------------------------"
   echo -e ${RST}

   mv ${OUTDIR}/ResurrectionRemix*-${DEVICE}.zip "${ZIPMOVE}"
   mv ${OUTDIR}/ResurrectionRemix*-${DEVICE}.zip.md5sum "${ZIPMOVE}"



   # Upload the files
   echo -e ${BLDGREEN}
   echo -e "---------------"
   echo -e "UPLOADING FILES"
   echo -e "---------------"
   echo -e ${RST}
   echo -e ""

   . ${HOME}/upload.sh



   # Clean up out directory to free up space
   echo -e ""
   echo -e ${BLDGREEN}
   echo -e "------------------------------------------"
   echo -e "CLEANING UP ${SOURCEDIR}/out"
   echo -e "------------------------------------------"
   echo -e ${RST}
   echo -e ""

   make clobber



   # Go back home
   echo -e ${BLDGREEN}
   echo -e "----------"
   echo -e "GOING HOME"
   echo -e "----------"
   echo -e ${RST}

   cd ${HOME}

# If the build failed, add a variable
else
   BUILD_RESULT_STRING="BUILD FAILED"

fi



# Stop tracking time
END=$(date +%s)
echo -e ${BLDGREEN}
echo -e "-------------------------------------"
echo -e "SCRIPT ENDING AT $(date +%D\ %r)"
echo -e ""
echo -e "${BUILD_RESULT_STRING}!"
echo -e "TIME: $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')"
echo -e "-------------------------------------"
echo -e ${RST}

# Add line to compile log
echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${DEVICE}" >> ${COMPILE_LOG}
echo -e "${BUILD_RESULT_STRING} IN $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')\n" >> ${COMPILE_LOG}

echo -e "\a"
