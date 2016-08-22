#!/bin/bash

# -----
# Usage
# -----
# For one device build:
# $ . rom.sh <me|rom> <device> (person)
# For all device builds:
# $ . rom.sh all <rom>



# --------
# Examples
# --------
# $ . rom.sh pn angler sync
# $ . rom.sh du shamu nosync
# $ . rom.sh me
# $ . rom.sh all du jdizzle
# $ . rom.sh all pn-mod



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

# Creates a changelog in the upload directory
function changelog() {
   # ----------
   # Parameters
   # ----------
   # Parameter 1: The source directory
   # Parameter 2: The upload directory
   REPO_DIR=${1}
   FILE_MOVE=${2}

   export CHANGELOG="${FILE_MOVE}"/changelog.txt

   # If a changelog exists, remove it
   if [[ -f "${CHANGELOG}" ]]; then
   	rm -vrf "${CHANGELOG}"
   fi

   echo "Making ${CHANGELOG}"
   touch "${CHANGELOG}"

   echoText "GENERATING CHANGELOG"

   cd ${REPO_DIR}

   # Echos the git log to the changelog file for the past 10 days
   for i in $( seq 10 ); do
      export AFTER_DATE=$( TZ=MST date --date="$i days ago" +%m-%d-%Y )
      k=$( expr $i - 1 )
   	export UNTIL_DATE=$( TZ=MST date --date="$k days ago" +%m-%d-%Y )

   	# Line with after --- until was too long for a small ListView
   	echo '=======================' >> "${CHANGELOG}";
   	echo  "     "${UNTIL_DATE}     >> "${CHANGELOG}";
   	echo '=======================' >> "${CHANGELOG}";
   	echo >> "${CHANGELOG}";

   	# Cycle through every repo to find commits between 2 dates
   	repo forall -pc 'git log --oneline --after=${AFTER_DATE} --until=${UNTIL_DATE}' >> "${CHANGELOG}"
   	echo >> "${CHANGELOG}";
   done

   sed -i 's/project/   */g' "${CHANGELOG}"
}

# Compilation function
function compile() {
   # ----------
   # Parameters
   # ----------
   # Parameter 1: ROM to build (currently AICP, AOSiP, Dirty Unicorns, Pure Nexus [Mod], ResurrectionRemix, and Screw'd)
   # Parameter 2: Device (eg. angler, bullhead, shamu); not necessary for RR
   # Parameter 3: Pure Nexus Mod/test build or a personalized Dirty Unicorns build (omit if neither applies)

   # Unassign flags and reset DU_BUILD_TYPE, PURENEXUS_BUILD_TYPE, and LOCALVERSION
   export DU_BUILD_TYPE=
   export PURENEXUS_BUILD_TYPE=
   export LOCALVERSION=
   PERSON=
   TEST=false
   PERSONAL=false
   SUCCESS=false

   # If the first parameter is "me", I'm running a personal build; otherwise, it's a public build
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
                  PERSON=${3}
                  case "${PERSON}" in
                     "alcolawl")
                        export DU_BUILD_TYPE=ALCOLAWL ;;
                     "hmhb")
                        export DU_BUILD_TYPE=DIRTY-DEEDS ;;
                     "jdizzle")
                        export DU_BUILD_TYPE=ASYLUM ;;
                  esac ;;

               # And it's PN, we are running a test build
               "pn")
                  TEST=true ;;
            esac
         fi
      fi
   fi



   # ---------
   # Variables
   # ---------
   # ANDROID_DIR: Directory that holds all of the Android files (currently my home directory)
   # OUT_DIR: Output directory of completed ROM zip after compilation
   # SOURCE_DIR: Directory that holds the ROM source
   # ZIP_MOVE: Directory to hold completed ROM zips
   # ZIP_FORMAT: The format of the zip file in the out directory for moving to ZIP_MOVE
   ANDROID_DIR=${HOME}

   if [[ ${PERSONAL} = true ]]; then
      export PURENEXUS_BUILD_TYPE=CHANCELLOR
      SOURCE_DIR=${ANDROID_DIR}/ROMs/PN
      ZIP_MOVE=${HOME}/shared/.me
      ZIP_FORMAT=pure_nexus_${DEVICE}-*.zip

   else
      # Currently, we support AICP, AOSiP, Dirty Unicorns, Pure Nexus (Mod), ResurrectionRemix, and Screw'd
      case "${ROM}" in
         "aosip")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/AOSiP
            ZIP_MOVE=${HOME}/shared/ROMs/AOSiP/${DEVICE}
            ZIP_FORMAT=AOSiP-*-${DEVICE}-*.zip ;;
         "beltz")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/Beltz
            ZIP_MOVE=${HOME}/shared/ROMs/Beltz/${DEVICE}
            ZIP_FORMAT=beltz_mm*${DEVICE}.zip ;;
         "du")
            if [[ -n ${PERSON} ]]; then
               SOURCE_DIR=${ANDROID_DIR}/ROMs/DU
               ZIP_MOVE=${HOME}/shared/ROMs/.special/.${PERSON}
               ZIP_FORMAT=DU_${DEVICE}_*.zip
            else
               SOURCE_DIR=${ANDROID_DIR}/ROMs/DU
               ZIP_MOVE=${HOME}/shared/ROMs/DirtyUnicorns/${DEVICE}
               ZIP_FORMAT=DU_${DEVICE}_*.zip
            fi ;;
         "pn")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/PN
            if [[ ${TEST} = true ]]; then
               ZIP_MOVE=${HOME}/shared/ROMs/PureNexus/.tests/${DEVICE}
            else
               ZIP_MOVE=${HOME}/shared/ROMs/PureNexus/${DEVICE}
            fi
            ZIP_FORMAT=pure_nexus_${DEVICE}-*.zip ;;
         "pn-mod")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/PN-Mod
            ZIP_MOVE=${HOME}/shared/ROMs/PureNexusMod/${DEVICE}
            ZIP_FORMAT=pure_nexus_${DEVICE}-*.zip ;;
         "rr")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/RR
            ZIP_MOVE=${HOME}/shared/ROMs/ResurrectionRemix/${DEVICE}
            ZIP_FORMAT=ResurrectionRemix*-${DEVICE}.zip ;;
      esac
   fi

   OUT_DIR=${SOURCE_DIR}/out/target/product/${DEVICE}



   # Export the LOG variable for other files to use (I currently handle this via .bashrc)
   # export LOG_DIR=${HOME}/shared/.logs
   # export LOG=${LOG_DIR}/Results/compile_log_$( TZ=MST date +%m_%d_%y ).log



   # Clear the terminal
   clear



   # Start tracking time
   echoText "SCRIPT STARTING AT $( TZ=MST date +%D\ %r )"

   START=$( TZ=MST date +%s )



   # Change to the source directory
   echoText "MOVING TO SOURCE DIRECTORY"

   cd ${SOURCE_DIR}



   # Start syncing the latest sources
   echoText "SYNCING LATEST SOURCES"; newLine

   repo sync --force-sync -j$(grep -c ^processor /proc/cpuinfo)



   # If we are running a ResurrectionRemix build, let's cherry pick some commits first
   if [[ "${ROM}" ==  "rr" ]]; then
      # I could fork these repos and do the changes in there permanently but I don't want to have to maintain any extra repos

      newLine

      # 1. Do not block HOME if background incoming call (marshmallow)
      cd ${SOURCE_DIR}/frameworks/base
      git fetch https://github.com/nathanchance/android_frameworks_base.git
      git cherry-pick d073e3efe7328558528cf50f40f4152af439e71a
      # 2. Change DESOLATED to KBUILD_BUILD_HOST and allow kernel to be compiled with UBER 6.1
      cd ${SOURCE_DIR}/kernel/moto/shamu
      git fetch https://github.com/nathanchance/B14CKB1RD_Kernel_N6.git
      git cherry-pick 20f83cadace94da9b711ebb53661b1682885888a
      # 3. Change from shamu_defconfig to B14CKB1RD_defconfig
      cd ${SOURCE_DIR}/device/moto/shamu
      git fetch https://github.com/nathanchance/android_device_moto_shamu.git
      git cherry-pick 0d2c6f3bdfe6e78b9b8036471dd3dcb6945fbb51
      # 4. Remove the unnecessary decreased sound delays from notifications (thanks @IAmTheOneTheyCallNeo)
      git cherry-pick e2ad7f39bb2da832d1175fac3494cb1565741755
      # 5. Revert "shamu: correct naming of blob makefile in aosp_shamu.mk", as we use DU's vendor files
      git revert --no-edit 4a7970b9bba25f8c1b071756d389bfb54c856cde
      # 6. Stop per app overlays from being reset (thanks @bigrushdog)
      cd ${SOURCE_DIR}/packages/apps/ThemeChooser
      git fetch https://github.com/nathanchance/android_packages_apps_ThemeChooser.git
      git cherry-pick 1cefd98f7ac5db31754a8f7ee1fd62f3ac897b71
      # 7. Add @Yoinx's Kernel Adiutor-Mod instead of the regular Kernel Adiutor (to complement Blackbird)
      cd ${SOURCE_DIR}/vendor/cm/prebuilt/KernelAdiutor
      rm -rf KernelAdiutor.apk
      wget https://github.com/yoinx/kernel_adiutor/raw/master/download/app/app-release.apk
      mv app-release.apk KernelAdiutor.apk
      cd ${SOURCE_DIR}
      # I want to make sure the picks went through okay
      sleep 10
   elif [[ "${ROM}" == "du" ]]; then
      cd ${SOURCE_DIR}/build
      git fetch http://gerrit.dirtyunicorns.com/android_build refs/changes/94/1494/1 && git cherry-pick FETCH_HEAD
      cd ${SOURCE_DIR}
   fi


   # Setup the build environment
   echoText "SETTING UP BUILD ENVIRONMENT"; newLine

   . build/envsetup.sh



   # Prepare device
   echoText "PREPARING $( echo ${DEVICE} | awk '{print toupper($0)}' )"; newLine

   if [[ "${ROM}" == "beltz" ]]; then
      lunch androidx_${DEVICE}-userdebug
   else
      breakfast ${DEVICE}
   fi



   # Clean up
   echoText "CLEANING UP OUT DIRECTORY"; newLine

   mka clobber



   # Start building
   echoText "MAKING ZIP FILE"; newLine

   NOW=$( TZ=MST date +"%Y-%m-%d-%S" )
   time mka bacon 2>&1 | tee ${LOGDIR}/Compilation/${ROM}_${DEVICE}-${NOW}.log



   # If the compilation was successful, there will be a zip in the format above in the out directory
   if [[ $( ls ${OUT_DIR}/${ZIP_FORMAT} 2>/dev/null | wc -l ) != "0" ]]; then
      # Make the build result string show success
      BUILD_RESULT_STRING="BUILD SUCCESSFUL"
      SUCCESS=true



      # If the upload directory doesn't exist, make it; otherwise, remove existing files in ZIP_MOVE
      if [[ ! -d "${ZIP_MOVE}" ]]; then
         newLine; echoText "MAKING ZIP_MOVE DIRECTORY"

         mkdir -p "${ZIP_MOVE}"
      else
         newLine; echoText "CLEANING ZIP_MOVE DIRECTORY"; newLine

         rm -vrf "${ZIP_MOVE}"/*${ZIP_FORMAT}*
      fi



      # Copy new files to ZIP_MOVE
      newLine; echoText "MOVING FILES TO ZIP_MOVE DIRECTORY"; newLine

      mv -v ${OUT_DIR}/*${ZIP_FORMAT}* "${ZIP_MOVE}"



      newLine; changelog ${SOURCE_DIR} "${ZIP_MOVE}"



      # Upload the files
      echoText "UPLOADING FILES"; newLine

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
      SUCCESS=false
   fi



   # Stop tracking time
   END=$( TZ=MST date +%s )
   newLine; echoText "${BUILD_RESULT_STRING}!"

   # Print the zip location and its size if the script was successful
   if [[ ${SUCCESS} = true ]]; then
      echo -e ${RED}"ZIP: $( ls ${ZIP_MOVE}/${ZIP_FORMAT} )"
      echo -e "SIZE: $( du -h ${ZIP_MOVE}/${ZIP_FORMAT} | awk '{print $1}'  )"${RST}
   fi
   # Print the time the script finished and how long the script ran for regardless of success
   echo -e ${RED}"TIME FINISHED: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
   echo -e ${RED}"DURATION: $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )"${RST}; newLine

   # Add line to compile log
   if [[ ${PERSONAL} = true ]]; then
      echo -e "$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} me" >> ${LOG}
   elif [[ ${TEST} = true ]]; then
      echo -e "$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${ROM} test ${DEVICE}" >> ${LOG}
   elif [[ -n ${PERSON} ]]; then
      echo -e "$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${ROM} ${PERSON}" >> ${LOG}
   else
      echo -e "$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${ROM} ${DEVICE}" >> ${LOG}
   fi

   echo -e "${BUILD_RESULT_STRING} IN $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )\n" >> ${LOG}

   echo -e "\a"
}

# If the first parameter to the rom.sh script is "normal" or "release" followed by the rom type, we are running four or seven builds for the devices we support; otherwise, it is just one build with the parameters given
if [[ "${1}" == "normal" || "${1}" == "release" ]]; then
   case "${1}" in
      "normal")
         DEVICES="angler shamu bullhead hammerhead" ;;
      "release")
         DEVICES="angler shamu bullhead hammerhead flo deb flounder" ;;
   esac

   for DEVICE in ${DEVICES}; do
      compile ${2} ${DEVICE} ${3} ${4}
   done

   cd ${HOME}
   cat ${LOG}
else
   compile ${1} ${2} ${3} ${4}
fi
