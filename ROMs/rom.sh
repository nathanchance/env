#!/bin/bash

# -----
# Usage
# -----
# $ . rom.sh <me|rom> <device> <oms|mod|person> <oms>



# --------
# Examples
# --------
# $ . rom.sh pn angler sync
# $ . rom.sh du shamu nosync
# $ . rom.sh me



# ---------
# Functions
# ---------

function echoText() {
   RED="\033[01;31m"
   RST="\033[0m"

   echo -e ${RED}
   echo -e "$( for i in `seq ${#1}`; do echo -e "-\c"; done )"
   echo -e "${1}"
   echo -e "$( for i in `seq ${#1}`; do echo -e "-\c"; done )"
   echo -e ${RST}
}

function newLine() {
   echo -e ""
}

function compile() {
   # ----------
   # Parameters
   # ----------
   # Parameter 1: ROM to build (currently AICP, AOSiP, Dirty Unicorns, Pure Nexus [Mod], ResurrectionRemix, and Screw'd)
   # Parameter 2: Device (eg. angler, bullhead, shamu)
   # Parameter 3: Pure Nexus Mod/OMS or a personalized Dirty Unicorns build (omit if neither applies)

   # Unassign flags and reset DU_BUILD_TYPE
   export DU_BUILD_TYPE=CHANCELLOR
   PERSON=
   MOD=false
   TEST=false
   PERSONAL=false
   OMS=false

   if [[ "${1}" == "me" ]]; then
      PERSONAL=true
      DEVICE=angler

   else
      ROM=${1}

      # If the ROM is RR, its device is only Shamu
      if [[ "${ROM}" == "rr" ]]; then
         DEVICE=shamu

      else
         DEVICE=${2}

         # If there is a third parameter
         if [[ -n ${3} ]]; then
            # And it's DU, we are running a personalized build
            case "${ROM}" in
               "du")
                  case "${3}" in
                     "alcolawl")
                        export DU_BUILD_TYPE=ALCOLAWL ;;
                     "bre")
                        export DU_BUILD_TYPE=BREYANA ;;
                     "drew")
                        export DU_BUILD_TYPE=DREW ;;
                     "hmhb")
                        export DU_BUILD_TYPE=DIRTY-DEEDS ;;
                     "jdizzle")
                        export DU_BUILD_TYPE=NINJA ;;
                  esac ;;

               # And it's PN, we are running either a Mod, test, or OMS build; if there is a 4th parameter, it is a Mod OMS build
               "pn")
                  case "${3}" in
                     "mod")
                        MOD=true
                        if [[ -n ${4} && "${4}" == "oms" ]]; then
                           OMS=true
                        fi ;;
                     "test")
                        TEST=true ;;
                     "oms")
                        OMS=true ;;
                  esac ;;
            esac
         fi
      fi
   fi



   # ---------
   # Variables
   # ---------
   # ANDROIDDIR: Directory that holds all of the Android files (currently my home directory)
   # OUTDIR: Output directory of completed ROM zip after compilation
   # SOURCEDIR: Directory that holds the ROM source
   # ZIPMOVE: Directory to hold completed ROM zips
   # ZIPFORMAT: The format of the zip file in the out directory for moving to ZIPMOVE
   ANDROIDDIR=${HOME}

   if [[ ${PERSONAL} = true ]]; then
      SOURCEDIR=${ANDROIDDIR}/ROMs/PN-Mod-OMS
      ZIPMOVE=${HOME}/shared/.me
      ZIPFORMAT=pure_nexus_${DEVICE}-*.zip

   else
      case "${ROM}" in
         "aicp")
            SOURCEDIR=${ANDROIDDIR}/ROMs/AICP
            ZIPMOVE=${HOME}/shared/ROMs/AICP/${DEVICE}
            ZIPFORMAT=aicp_${DEVICE}_mm*.zip ;;
         "aosip")
            SOURCEDIR=${ANDROIDDIR}/ROMs/AOSiP
            ZIPMOVE=${HOME}/shared/ROMs/AOSiP/${DEVICE}
            ZIPFORMAT=AOSiP-*-${DEVICE}-*.zip ;;
         "du")
            if [[ -n ${PERSON} ]]; then
               SOURCEDIR=${ANDROIDDIR}/ROMs/DU
               ZIPMOVE=${HOME}/shared/ROMs/.special/.${PERSON}
               ZIPFORMAT=DU_${DEVICE}_*.zip
            else
               SOURCEDIR=${ANDROIDDIR}/ROMs/DU
               ZIPMOVE=${HOME}/shared/ROMs/"Dirty Unicorns"/${DEVICE}
               ZIPFORMAT=DU_${DEVICE}_*.zip
            fi ;;
         "pn")
            ZIPFORMAT=pure_nexus_${DEVICE}-*.zip

            case "${MOD}:${OMS}" in
               "true:true")
                  SOURCEDIR=${ANDROIDDIR}/ROMs/PN-Mod-OMS
                  ZIPMOVE=${HOME}/shared/ROMs/"Pure Nexus Mod OMS"/${DEVICE} ;;
               "true:false")
                  SOURCEDIR=${ANDROIDDIR}/ROMs/PN-Mod
                  ZIPMOVE=${HOME}/shared/ROMs/"Pure Nexus Mod"/${DEVICE} ;;
               "false:true")
                  SOURCEDIR=${ANDROIDDIR}/ROMs/PN-OMS
                  ZIPMOVE=${HOME}/shared/ROMs/"Pure Nexus"/.oms/${DEVICE} ;;
               "false:false")
                  SOURCEDIR=${ANDROIDDIR}/ROMs/PN
                  if [[ ${TEST} = true ]]; then
                     ZIPMOVE=${HOME}/shared/ROMs/"Pure Nexus"/.tests/${DEVICE}
                  else
                     ZIPMOVE=${HOME}/shared/ROMs/"Pure Nexus"/${DEVICE}
                  fi ;;
            esac ;;
         "rr")
            SOURCEDIR=${ANDROIDDIR}/ROMs/RR
            ZIPMOVE=${HOME}/shared/ROMs/ResurrectionRemix/${DEVICE}
            ZIPFORMAT=ResurrectionRemix*-${DEVICE}.zip ;;
         "screwd")
            SOURCEDIR=${ANDROIDDIR}/ROMs/Screwd
            ZIPMOVE=${HOME}/shared/ROMs/"Screw'd"/${DEVICE}
            ZIPFORMAT=screwd-*${SCREWD_BUILD_TYPE}*.zip ;;
      esac
   fi

   OUTDIR=${SOURCEDIR}/out/target/product/${DEVICE}



   # Export the COMPILE_LOG variable for other files to use (I currently handle this via .bashrc)
   # export LOGDIR=${ANDROIDDIR}/Logs
   # export COMPILE_LOG=${LOGDIR}/compile_log_`date +%m_%d_%y`.log



   # Clear the terminal
   clear



   # Start tracking time
   echoText "SCRIPT STARTING AT $(date +%D\ %r)"

   START=$(date +%s)



   # Change to the source directory
   echoText "MOVING TO SOURCE DIRECTORY"

   cd ${SOURCEDIR}



   echoText "SYNCING LATEST SOURCES"; newLine

   repo sync --force-sync


   if [[ "${ROM}" ==  "rr" ]]; then
      # I could fork these repos and do the changes in there permanently but I don't want to have to maintains anything extra

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
   echoText "SETTING UP BUILD ENVIRONMENT"; newLine

   . build/envsetup.sh



   # Prepare device
   echoText "PREPARING DEVICE"; newLine

   if [[ "${ROM}" == "screwd" ]]; then
      lunch screwd_${DEVICE}-userdebug
   else
      breakfast ${DEVICE}
   fi


   # Clean up
   echoText "CLEANING UP OUT DIRECTORY"; newLine

   mka clobber



   # Start building
   echoText "MAKING ZIP FILE"; newLine

   time mka bacon



   # If the compilation was successful
   if [[ `ls ${OUTDIR}/${ZIPFORMAT} 2>/dev/null | wc -l` != "0" ]]; then
      BUILD_RESULT_STRING="BUILD SUCCESSFUL"



      # Remove existing files in ZIPMOVE
      newLine; echoText "CLEANING ZIPMOVE DIRECTORY"

      if [[ ${ROM} == "pn" && ${MOD} = true && ${OMS} = true && ${DEVICE} == "angler" && ${PERSONAL} = false ]]; then
         rm -vrf ${HOME}/shared/.me/*${ZIPFORMAT}*
      fi

      rm -vrf "${ZIPMOVE}"/*${ZIPFORMAT}*



      # Copy new files to ZIPMOVE
      echoText "MOVING FILES TO ZIPMOVE DIRECTORY"; newLine

      if [[ ${ROM} == "pn" && ${MOD} = true && ${OMS} = true && ${DEVICE} == "angler" && ${PERSONAL} = false ]]; then
         cp -v ${OUTDIR}/*${ZIPFORMAT}* ${HOME}/shared/.me
      fi

      mv -v ${OUTDIR}/*${ZIPFORMAT}* "${ZIPMOVE}"




      # Upload the files
      newLine; echoText "UPLOADING FILES"; newLine

      . ${HOME}/upload.sh



      # Clean up out directory to free up space
      newLine; echoText "CLEANING UP OUT DIRECTORY"; newLine

      mka clobber



      # Go back home
      echoText "GOING HOME"

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
   if [[ ${PERSONAL} = true ]]; then
      echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} me" >> ${COMPILE_LOG}
   elif [[ ${MOD} = true && ${OMS} = false ]]; then
      echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} mod ${DEVICE}" >> ${COMPILE_LOG}
   elif [[ ${MOD} = true && ${OMS} = true ]]; then
      echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} mod oms ${DEVICE}" >> ${COMPILE_LOG}
   elif [[ ${MOD} = false && ${OMS} = true ]]; then
      echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} oms ${DEVICE}" >> ${COMPILE_LOG}
   elif [[ ${TEST} = true ]]; then
      echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} test ${DEVICE}" >> ${COMPILE_LOG}
   elif [[ -n ${PERSON} ]]; then
      echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} ${PERSON}" >> ${COMPILE_LOG}
   else
      echo -e "`date +%H:%M:%S`: ${BASH_SOURCE} ${ROM} ${DEVICE}" >> ${COMPILE_LOG}
   fi

   echo -e "${BUILD_RESULT_STRING} IN $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')\n" >> ${COMPILE_LOG}

   echo -e "\a"
}

if [[ "${1}" == "all" ]]; then
   DEVICES="angler shamu bullhead hammerhead"

   for DEVICE in ${DEVICES}; do
      compile ${2} ${DEVICE} ${3} ${4}
   done

   cd ${HOME}
   cat ${COMPILE_LOG}
else
   compile ${1} ${2} ${3} ${4}
fi
