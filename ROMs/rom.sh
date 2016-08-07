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
   echo -e "$( for i in $( seq ${#1} ); do echo -e "-\c"; done )"
   echo -e "${1}"
   echo -e "$( for i in $( seq ${#1} ); do echo -e "-\c"; done )"
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
   REPODIR=${1}
   FILEMOVE=${2}

   export CHANGELOG="${FILEMOVE}"/changelog.txt

   # If a changelog exists, remove it
   if [[ -f "${CHANGELOG}" ]]; then
   	rm -vrf "${CHANGELOG}"
   fi

   echo "Making ${CHANGELOG}"
   touch "${CHANGELOG}"

   echoText "GENERATING CHANGELOG"

   cd ${REPODIR}

   # Echos the git log to the changelog file for the past 10 days
   for i in $( seq 10 ); do
      export AFTER_DATE=$( date --date="$i days ago" +%m-%d-%Y )
      k=$( expr $i - 1 )
   	export UNTIL_DATE=$( date --date="$k days ago" +%m-%d-%Y )

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
   # Parameter 1:   ROM to build (currently AICP, AOSiP, Dirty Unicorns, Pure Nexus [Mod], ResurrectionRemix, and Screw'd)
   # Parameter 2:   Device (eg. angler, bullhead, shamu); not necessary for RR
   # Parameter 3: Pure Nexus Mod/test build or a personalized Dirty Unicorns build (omit if neither applies)

   # Unassign flags and reset DU_BUILD_TYPE, PURENEXUS_BUILD_TYPE, and LOCALVERSION
   export DU_BUILD_TYPE=
   export PURENEXUS_BUILD_TYPE=
   export LOCALVERSION=
   PERSON=
   TEST=false
   PERSONAL=false

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
   # ANDROIDDIR: Directory that holds all of the Android files (currently my home directory)
   # OUTDIR: Output directory of completed ROM zip after compilation
   # SOURCEDIR: Directory that holds the ROM source
   # ZIPMOVE: Directory to hold completed ROM zips
   # ZIPFORMAT: The format of the zip file in the out directory for moving to ZIPMOVE
   ANDROIDDIR=${HOME}

   if [[ ${PERSONAL} = true ]]; then
      export PURENEXUS_BUILD_TYPE=CHANCELLOR
      SOURCEDIR=${ANDROIDDIR}/ROMs/PN
      ZIPMOVE=${HOME}/shared/.me
      ZIPFORMAT=pure_nexus_${DEVICE}-*.zip

   else
      # Currently, we support AICP, AOSiP, Dirty Unicorns, Pure Nexus (Mod), ResurrectionRemix, and Screw'd
      case "${ROM}" in
         "aosip")
            SOURCEDIR=${ANDROIDDIR}/ROMs/AOSiP
            ZIPMOVE=${HOME}/shared/ROMs/AOSiP/${DEVICE}
            ZIPFORMAT=AOSiP-*-${DEVICE}-*.zip ;;
         "beltz")
            SOURCEDIR=${ANDROIDDIR}/ROMs/Beltz
            ZIPMOVE=${HOME}/shared/ROMs/Beltz/${DEVICE}
            ZIPFORMAT=beltz_mm*${DEVICE}.zip ;;
         "du")
            if [[ -n ${PERSON} ]]; then
               SOURCEDIR=${ANDROIDDIR}/ROMs/DU
               ZIPMOVE=${HOME}/shared/ROMs/.special/.${PERSON}
               ZIPFORMAT=DU_${DEVICE}_*.zip
            else
               SOURCEDIR=${ANDROIDDIR}/ROMs/DU
               ZIPMOVE=${HOME}/shared/ROMs/DirtyUnicorns/${DEVICE}
               ZIPFORMAT=DU_${DEVICE}_*.zip
            fi ;;
         "pn")
            SOURCEDIR=${ANDROIDDIR}/ROMs/PN
            if [[ ${TEST} = true ]]; then
               ZIPMOVE=${HOME}/shared/ROMs/PureNexus/.tests/${DEVICE}
            else
               ZIPMOVE=${HOME}/shared/ROMs/PureNexus/${DEVICE}
            fi
            ZIPFORMAT=pure_nexus_${DEVICE}-*.zip ;;
         "pn-mod")
            SOURCEDIR=${ANDROIDDIR}/ROMs/PN-Mod
            ZIPMOVE=${HOME}/shared/ROMs/PureNexusMod/${DEVICE}
            ZIPFORMAT=pure_nexus_${DEVICE}-*.zip ;;
         "rr")
            SOURCEDIR=${ANDROIDDIR}/ROMs/RR
            ZIPMOVE=${HOME}/shared/ROMs/ResurrectionRemix/${DEVICE}
            ZIPFORMAT=ResurrectionRemix*-${DEVICE}.zip ;;
      esac
   fi

   OUTDIR=${SOURCEDIR}/out/target/product/${DEVICE}



   # Export the LOG variable for other files to use (I currently handle this via .bashrc)
   # export LOGDIR=${HOME}/shared/.logs
   # export LOG=${LOGDIR}/Results/compile_log_$( date +%m_%d_%y ).log



   # Clear the terminal
   clear



   # Start tracking time
   echoText "SCRIPT STARTING AT $( date +%D\ %r )"

   START=$( date +%s )



   # Change to the source directory
   echoText "MOVING TO SOURCE DIRECTORY"

   cd ${SOURCEDIR}



   # Start syncing the latest sources
   echoText "SYNCING LATEST SOURCES"; newLine

   repo sync --force-sync



   # If we are running a ResurrectionRemix build, let's cherry pick some commits first
   if [[ "${ROM}" ==  "rr" ]]; then
      # I could fork these repos and do the changes in there permanently but I don't want to have to maintain any extra repos

      newLine

      # 1. Do not block HOME if background incoming call (marshmallow)
      cd ${SOURCEDIR}/frameworks/base
      git fetch https://github.com/nathanchance/android_frameworks_base.git
      git cherry-pick d073e3efe7328558528cf50f40f4152af439e71a
      # 2. Change DESOLATED to KBUILD_BUILD_HOST and allow kernel to be compiled with UBER 6.1
      cd ${SOURCEDIR}/kernel/moto/shamu
      git fetch https://github.com/nathanchance/B14CKB1RD_Kernel_N6.git
      git cherry-pick 20f83cadace94da9b711ebb53661b1682885888a
      # 3. Change from shamu_defconfig to B14CKB1RD_defconfig
      cd ${SOURCEDIR}/device/moto/shamu
      git fetch https://github.com/nathanchance/android_device_moto_shamu.git
      git cherry-pick 0d2c6f3bdfe6e78b9b8036471dd3dcb6945fbb51
      # 4. Stop per app overlays from being reset (thanks @bigrushdog)
      cd ${SOURCEDIR}/packages/apps/ThemeChooser
      git fetch https://github.com/nathanchance/android_packages_apps_ThemeChooser.git
      git cherry-pick 1cefd98f7ac5db31754a8f7ee1fd62f3ac897b71
      # 5. Add @Yoinx's Kernel Adiutor-Mod instead of the regular Kernel Adiutor (to complement Blackbird)
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

   NOW=$( date +"%Y-%m-%d-%S" )
   time mka bacon 2>&1 | tee ${LOGDIR}/Compilation/${ROM}_${DEVICE}-${NOW}.log



   # If the compilation was successful, there will be a zip in the format above in the out directory
   if [[ $( ls ${OUTDIR}/${ZIPFORMAT} 2>/dev/null | wc -l ) != "0" ]]; then
      # Make the build result string show success
      BUILD_RESULT_STRING="BUILD SUCCESSFUL"



      # If the upload directory doesn't exist, make it; otherwise, remove existing files in ZIPMOVE
      if [[ ! -d "${ZIPMOVE}" ]]; then
         newLine; echoText "MAKING ZIPMOVE DIRECTORY"

         mkdir -p "${ZIPMOVE}"
      else
         newLine; echoText "CLEANING ZIPMOVE DIRECTORY"; newLine

         rm -vrf "${ZIPMOVE}"/*${ZIPFORMAT}*
      fi



      # Copy new files to ZIPMOVE
      newLine; echoText "MOVING FILES TO ZIPMOVE DIRECTORY"; newLine

      mv -v ${OUTDIR}/*${ZIPFORMAT}* "${ZIPMOVE}"



      newLine; changelog ${SOURCEDIR} "${ZIPMOVE}"



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
   fi



   # Stop tracking time
   END=$( date +%s )
   echo -e ${RED}
   echo -e "-------------------------------------"
   echo -e "SCRIPT ENDING AT $( date +%D\ %r )"
   echo -e ""
   echo -e "${BUILD_RESULT_STRING}!"
   echo -e "TIME: $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )"
   echo -e "-------------------------------------"
   echo -e ${RST}; newLine

   # Add line to compile log
   if [[ ${PERSONAL} = true ]]; then
      echo -e "$( date +%H:%M:%S ): ${BASH_SOURCE} me" >> ${LOG}
   elif [[ ${TEST} = true ]]; then
      echo -e "$( date +%H:%M:%S ): ${BASH_SOURCE} ${ROM} test ${DEVICE}" >> ${LOG}
   elif [[ -n ${PERSON} ]]; then
      echo -e "$( date +%H:%M:%S ): ${BASH_SOURCE} ${ROM} ${PERSON}" >> ${LOG}
   else
      echo -e "$( date +%H:%M:%S ): ${BASH_SOURCE} ${ROM} ${DEVICE}" >> ${LOG}
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
