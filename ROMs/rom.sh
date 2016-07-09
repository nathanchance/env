#!/bin/bash

# -----
# Usage
# -----
# $ . rom.sh <me|rom> <device> <sync|nosync> <mod|person>



# --------
# Examples
# --------
# $ . rom.sh pn angler sync
# $ . rom.sh du shamu nosync
# $ . rom.sh me



# ----------
# Parameters
# ----------
# Parameter 1: ROM to build (currently AICP, AOSiP, Dirty Unicorns, Pure Nexus [Mod], ResurrectionRemix, and Screw'd)
# Parameter 2: Device (eg. angler, bullhead, shamu)
# Parameter 3: Whether or not to run repo sync
# Parameter 4: Pure Nexus Mod or a personalized Dirty Unicorns build (omit if neither applies)
if [ "${1}" == "me" ]
then
   PERSONAL=true
   DEVICE=angler
   SYNC=sync
else
   ROM=${1}

   # If the ROM is RR, it only needs a sync parameter since I only build Shamu
   if [ "${ROM}" == "rr" ]
   then
      SYNC=${2}
      DEVICE=shamu
   else
      DEVICE=${2}
      SYNC=${3}

      # If there is a fourth parameter
      if [[ -n ${4} ]]
      then
         # And it's DU, we are running a personalized build
         if [ "${ROM}" == "du" ]
         then
            PERSON=${4}

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

         # And it's PN, we are running a Mod build
         if [ "${ROM}" == "pn" ]
         then
            if [ "${4}" == "mod" ]
            then
               MOD=true
               # If there is a fifth parameter
               if [[ -n ${5} ]]
               then
                  OMS=true
               fi
            elif [ "${4}" == "test" ]
            then
               TEST=true
            elif [ "${4}" == "oms" ]
            then
               OMS=true
            fi
         fi
      fi
   fi
fi



# ---------
# Variables
# ---------
# ANDROIDDIR: Directory that holds all of the Android files (currently my home directory)
# SOURCEDIR: Directory that holds the ROM source
# ZIPMOVE: Directory to hold completed ROM zips
# ZIPFORMAT: The format of the zip file in the out directory for moving to ZIPMOVE
# OUTDIR: Output directory of completed ROM zip after compilation
ANDROIDDIR=${HOME}

if [[ ${PERSONAL} = true ]]
then
   SOURCEDIR=${ANDROIDDIR}/ROMs/PN-Mod
   ZIPMOVE=${HOME}/shared/.me
   ZIPFORMAT=pure_nexus_${DEVICE}-*.zip
else
   if [ "${ROM}" == "aicp" ]
   then
      SOURCEDIR=${ANDROIDDIR}/ROMs/AICP
      ZIPMOVE=${HOME}/shared/ROMs/AICP/${DEVICE}
      ZIPFORMAT=aicp_${DEVICE}_mm*.zip

   elif [ "${ROM}" == "aosip" ]
   then
      SOURCEDIR=${ANDROIDDIR}/ROMs/AOSiP
      ZIPMOVE=${HOME}/shared/ROMs/AOSiP/${DEVICE}
      ZIPFORMAT=AOSiP-*-${DEVICE}-*.zip

   elif [[ "${ROM}" == "du" && -z ${PERSON} ]]
   then
      SOURCEDIR=${ANDROIDDIR}/ROMs/DU
      ZIPMOVE=${HOME}/shared/ROMs/"Dirty Unicorns"/${DEVICE}
      ZIPFORMAT=DU_${DEVICE}_*.zip

   elif [[ "${ROM}" == "du" && -n ${PERSON} ]]
   then
      SOURCEDIR=${ANDROIDDIR}/ROMs/DU
      ZIPMOVE=${HOME}/shared/ROMs/.special/.${PERSON}
      ZIPFORMAT=DU_${DEVICE}_*.zip

   elif [[ "${ROM}" == "pn" ]]
   then
      if [[ ${MOD} = true ]]
      then
         SOURCEDIR=${ANDROIDDIR}/ROMs/PN-Mod
      elif [[ ${OMS} = true && ${MOD} = false ]]
      then
         SOURCEDIR=${ANDROIDDIR}/ROMs/PN-OMS
      else
         SOURCEDIR=${ANDROIDDIR}/ROMs/PN
      fi

      if [[ ${MOD} = true && ${OMS} = false ]]
      then
         ZIPMOVE=${HOME}/shared/ROMs/"Pure Nexus Mod"/${DEVICE}
      elif [[ ${MOD} = true && ${OMS} = true ]]
      then
         ZIPMOVE=${HOME}/shared/ROMs/"Pure Nexus Mod"/.oms/${DEVICE}
      elif [[ ${OMS} = true && ${MOD} = false ]]
      then
         ZIPMOVE=${HOME}/shared/ROMs/"Pure Nexus"/.oms/${DEVICE}
      elif [[ ${TEST} = true ]]
      then
         ZIPMOVE=${HOME}/shared/ROMs/"Pure Nexus"/.tests/${DEVICE}
      else
         ZIPMOVE=${HOME}/shared/ROMs/"Pure Nexus"/${DEVICE}
      fi

      ZIPFORMAT=pure_nexus_${DEVICE}-*.zip

   elif [ "${ROM}" == "rr" ]
   then
      SOURCEDIR=${ANDROIDDIR}/ROMs/RR
      ZIPMOVE=${HOME}/shared/ROMs/ResurrectionRemix/${DEVICE}
      ZIPFORMAT=ResurrectionRemix*-${DEVICE}.zip

   elif [ "${ROM}" == "screwd" ]
   then
      SOURCEDIR=${ANDROIDDIR}/ROMs/Screwd
      ZIPMOVE=${HOME}/shared/ROMs/"Screw'd"/${DEVICE}
      ZIPFORMAT=screwd-*${SCREWD_BUILD_TYPE}*.zip
   fi
fi

OUTDIR=${SOURCEDIR}/out/target/product/${DEVICE}



# ------
# Colors
# ------
RED="\033[01;31m"
RST="\033[0m"



# Export the COMPILE_LOG variable for other files to use (I currently handle this via .bashrc)
# export LOGDIR=${ANDROIDDIR}/Logs
# export COMPILE_LOG=${LOGDIR}/compile_log_`date +%m_%d_%y`.log



# Clear the terminal
clear



# Start tracking time
echo -e ${RED}
echo -e "---------------------------------------"
echo -e "SCRIPT STARTING AT $(date +%D\ %r)"
echo -e "---------------------------------------"
echo -e ${RST}

START=$(date +%s)



# Change to the source directory
echo -e ${RED}
echo -e "--------------------------"
echo -e "MOVING TO SOURCE DIRECTORY"
echo -e "--------------------------"
echo -e ${RST}

cd ${SOURCEDIR}



# If we are running a PN Mod build with OMS, copy over our local manifest
if [[ ${MOD} = true && ${OMS} = true ]]
then
  rm -rf ${SOURCEDIR}/.repo/local_manifests/*.xml
  cp ${ANDROIDDIR}/ROMs/Manifests/pn-mod-oms.xml ${SOURCEDIR}/.repo/local_manifests
fi



# Sync the repo if requested
if [ "${SYNC}" == "sync" ]
then
   echo -e ${RED}
   echo -e "----------------------"
   echo -e "SYNCING LATEST SOURCES"
   echo -e "----------------------"
   echo -e ${RST}
   echo -e ""

   repo sync --force-sync
fi


if [ "${ROM}" ==  "rr" ]
then
   # I could fork these repos and do the changes in there permanently but I don't want to have to maintains anything extra
   echo -e ${RED}
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
fi


# Setup the build environment
echo -e ${RED}
echo -e "----------------------------"
echo -e "SETTING UP BUILD ENVIRONMENT"
echo -e "----------------------------"
echo -e ${RST}
echo -e ""

. build/envsetup.sh



# Prepare device
echo -e ${RED}
echo -e "----------------"
echo -e "PREPARING DEVICE"
echo -e "----------------"
echo -e ${RST}
echo -e ""

if [ "${ROM}" == "screwd" ]
then
   lunch screwd_${DEVICE}-userdebug
else
   breakfast ${DEVICE}
fi


# Clean up
echo -e ${RED}
echo -e "-------------------------"
echo -e "CLEANING UP OUT DIRECTORY"
echo -e "-------------------------"
echo -e ${RST}
echo -e ""

mka clobber



# Start building
echo -e ${RED}
echo -e "---------------"
echo -e "MAKING ZIP FILE"
echo -e "---------------"
echo -e ${RST}
echo -e ""

time mka bacon



# If the compilation was successful
if [ `ls ${OUTDIR}/${ZIPFORMAT} 2>/dev/null | wc -l` != "0" ]
then
   BUILD_RESULT_STRING="BUILD SUCCESSFUL"



   # Remove existing files in ZIPMOVE
   echo -e ""
   echo -e ${RED}
   echo -e "--------------------------"
   echo -e "CLEANING ZIPMOVE DIRECTORY"
   echo -e "--------------------------"
   echo -e ${RST}

   if [[ ${ROM} == "pn" && ${MOD} = true && ${DEVICE} == "angler" && -z ${PERSONAL} ]]
   then
      rm -rf ${HOME}/shared/.me/*${ZIPFORMAT}*
   fi

   rm -rf "${ZIPMOVE}"/*${ZIPFORMAT}*



   # Copy new files to ZIPMOVE
   echo -e ${RED}
   echo -e "---------------------------------"
   echo -e "MOVING FILES TO ZIPMOVE DIRECTORY"
   echo -e "---------------------------------"
   echo -e ${RST}
   echo -e ""

   if [[ ${ROM} == "pn" && ${MOD} = true && ${DEVICE} == "angler" && -z ${PERSONAL} ]]
   then
      cp -v ${OUTDIR}/*${ZIPFORMAT}* ${HOME}/shared/.me
   fi

   mv -v ${OUTDIR}/*${ZIPFORMAT}* "${ZIPMOVE}"




   # Upload the files
   echo -e ""
   echo -e ${RED}
   echo -e "---------------"
   echo -e "UPLOADING FILES"
   echo -e "---------------"
   echo -e ${RST}
   echo -e ""

   . ${HOME}/upload.sh



   # Clean up out directory to free up space
   echo -e ""
   echo -e ${RED}
   echo -e "-------------------------"
   echo -e "CLEANING UP OUT DIRECTORY"
   echo -e "-------------------------"
   echo -e ${RST}
   echo -e ""

   mka clobber



   # Go back home
   echo -e ${RED}
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
echo -e ${RED}
echo -e "-------------------------------------"
echo -e "SCRIPT ENDING AT $(date +%D\ %r)"
echo -e ""
echo -e "${BUILD_RESULT_STRING}!"
echo -e "TIME: $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')"
echo -e "-------------------------------------"
echo -e ${RST}

# Add line to compile log
if [[ ${PERSONAL} = true ]]
then
   echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} me" >> ${COMPILE_LOG}
elif [[ ${MOD} = true && ${OMS} = false ]]
then
   echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} mod ${DEVICE}" >> ${COMPILE_LOG}
elif [[ ${MOD} = true && ${OMS} = true ]]
then
   echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} mod oms ${DEVICE}" >> ${COMPILE_LOG}
elif [[ ${MOD} = false && ${OMS} = true ]]
then
   echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} oms ${DEVICE}" >> ${COMPILE_LOG}
elif [[ ${TEST} = true ]]
then
   echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} test ${DEVICE}" >> ${COMPILE_LOG}
elif [[ -n ${PERSON} ]]
then
   echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} ${PERSON}" >> ${COMPILE_LOG}
else
   echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} ${DEVICE}" >> ${COMPILE_LOG}
fi
echo -e "${BUILD_RESULT_STRING} IN $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')\n" >> ${COMPILE_LOG}

if [[ ${MOD} = true && ${OMS} = true ]]
then
   rm -rf ${SOURCEDIR}/.repo/local_manifests/*.xml
   cp ${ANDROIDDIR}/ROMs/Manifests/pn-mod.xml ${SOURCEDIR}/.repo/local_manifests
fi

# Unassign flags and reset DU_BUILD_TYPE
export DU_BUILD_TYPE=CHANCELLOR
PERSON=
MOD=false
TEST=false
PERSONAL=false
OMS=false

echo -e "\a"
