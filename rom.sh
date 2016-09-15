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
      if [[ -n ${1} ]]; then
         ROM=${1}
      else
         echo "ROM selection"
         echo "   1. PureNexus"
         echo "   2. PureNexus Mod"
         echo "   3. Dirty Unicorns"
         echo "   4. AOSiP"

         read -p "Which ROM would you like to build? " ROM_NUM

         case ${ROM_NUM} in
            "1")
               ROM=pn ;;
            "2")
               ROM=pn-mod ;;
            "3")
               ROM=du ;;
            "4")
               ROM=aosip ;;
            *)
               echo "Invalid selection, please run the script again" && return
         esac
      fi

      # If the ROM is RR, its device is only Shamu
      if [[ "${ROM}" == "rr" ]]; then
         DEVICE=shamu

      else
         if [[ -n ${2} ]]; then
            DEVICE=${2}
         else
            echo "Device selection"
            echo "   1. Angler"
            echo "   2. Bullhead"
            echo "   3. Shamu"

            read -p "Which device would you like to build for? " DEVICE_NUM

            case ${DEVICE_NUM} in
               "1")
                  DEVICE=angler ;;
               "2")
                  DEVICE=bullhead ;;
               "3")
                  DEVICE=shamu ;;
               *)
                  echo "Invalid selection, please run the script again" && return
            esac

            read DEVICE
         fi

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
      ZIP_MOVE=${HOME}/Completed/Zips/ROMs/Me
      ZIP_FORMAT=pure_nexus_${DEVICE}-*.zip

   else
      case "${ROM}" in
         "aosip")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/AOSiP
            ZIP_MOVE=${HOME}/Completed/Zips/ROMs/AOSiP/${DEVICE}
            ZIP_FORMAT=AOSiP-*-${DEVICE}-*.zip ;;
         # "beltz")
         #    SOURCE_DIR=${ANDROID_DIR}/ROMs/Beltz
         #    ZIP_MOVE=${HOME}/Completed/Zips/ROMs/Beltz/${DEVICE}
         #    ZIP_FORMAT=beltz_mm*${DEVICE}.zip ;;
         "du")
            if [[ -n ${PERSON} ]]; then
               SOURCE_DIR=${ANDROID_DIR}/ROMs/DU
               ZIP_MOVE=${HOME}/Completed/Zips/ROMs/.special/.${PERSON}
               ZIP_FORMAT=DU_${DEVICE}_*.zip
            else
               SOURCE_DIR=${ANDROID_DIR}/ROMs/DU
               ZIP_MOVE=${HOME}/Completed/Zips/ROMs/DirtyUnicorns/${DEVICE}
               ZIP_FORMAT=DU_${DEVICE}_*.zip
            fi ;;
         "pn")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/PN
            if [[ ${TEST} = true ]]; then
               ZIP_MOVE=${HOME}/Completed/Zips/ROMs/PureNexus/.tests/${DEVICE}
            else
               ZIP_MOVE=${HOME}/Completed/Zips/ROMs/PureNexus/${DEVICE}
            fi
            ZIP_FORMAT=pure_nexus_${DEVICE}-*.zip ;;
         "pn-mod")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/PN-Mod
            ZIP_MOVE=${HOME}/Completed/Zips/ROMs/PureNexusMod/${DEVICE}
            ZIP_FORMAT=pnmod_nexus_${DEVICE}-*.zip ;;
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



   # If we are running a personal build, make sure to include su
   # if [[ ${PERSONAL} = true ]]; then
   #    . update-su.sh
   # fi



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
      # echoText "UPLOADING FILES"; newLine



      # Clean up out directory to free up space
      newLine; echoText "CLEANING UP OUT DIRECTORY"; newLine

      mka clobber
      # if [[ ${PERSONAL} = true ]]; then
      #    rm -rf ${SOURCE_DIR}/device/huawei/angler/su
      # fi


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
