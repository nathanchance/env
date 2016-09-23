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


# Compilation function
function compile() {
   # ----------
   # Parameters
   # ----------
   # Parameter 1: ROM to build (currently AOSiP, Dirty Unicorns, Pure Nexus, and Pure Nexus Mod)
   # Parameter 2: Device (eg. angler, bullhead, shamu)

   # Unassign flags and reset ROM_BUILD_TYPE
   unset ROM_BUILD_TYPE
   PERSONAL=false
   SUCCESS=false

   # If the first parameter is "me", I'm running a personal build; otherwise, it's a public build
   if [[ "${1}" == "me" ]]; then
      PERSONAL=true
      DEVICE=angler

   else
      # If there is a first parameter defined, this is the ROM variable
      if [[ -n ${1} ]]; then
         ROM=${1}
      # Otherwise, prompt for it
      else
         echo "ROM selection"
         echo "   1. Pure Nexus"
         echo "   2. Pure Nexus Mod"
         echo "   3. Dirty Unicorns"
         echo "   4. AOSiP"
         echo "   5. MapleAOSP"
         echo "   6. SimpleAOSP"

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
            "5")
               ROM=maple ;;
            "6")
               ROM=saosp ;;
            *)
               echo "Invalid selection, please run the script again" && exit
         esac
      fi

      # If there is a second parameter defined, this is the device variable
      if [[ -n ${2} ]]; then
         DEVICE=${2}
      # Otherwise, prompt for it
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
               echo "Invalid selection, please run the script again" && exit
         esac
      fi
   fi



   # ---------
   # Variables
   # ---------
   # ANDROID_DIR: Directory that holds all of the Android files (currently my home directory)
   # OUT_DIR: Directory that holds the compiled ROM files
   # SOURCE_DIR: Directory that holds the ROM source
   # ZIP_MOVE: Directory to hold completed ROM zips
   # ZIP_FORMAT: The format of the zip file in the out directory for moving to ZIP_MOVE
   ANDROID_DIR=${HOME}

   # If we are running a personal build, define the above variable specially
   if [[ ${PERSONAL} = true ]]; then
      export ROM_BUILD_TYPE=CHANCELLOR
      SOURCE_DIR=${ANDROID_DIR}/ROMs/PN
      ZIP_MOVE=${HOME}/Completed/Zips/ROMs/Me
      ZIP_FORMAT=pure_nexus_${DEVICE}-7*.zip

   else
      # Otherwise, define them for our various ROMs
      case "${ROM}" in
         "aosip")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/AOSiP
            ZIP_MOVE=${HOME}/Completed/Zips/ROMs/AOSiP/${DEVICE}
            ZIP_FORMAT=AOSiP-*-${DEVICE}-*.zip ;;
         "du")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/DU
            ZIP_MOVE=${HOME}/Completed/Zips/ROMs/DirtyUnicorns/${DEVICE}
            ZIP_FORMAT=DU_${DEVICE}_*.zip ;;
         "maple")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/MapleAOSP
            ZIP_MOVE=${HOME}/Completed/Zips/ROMs/MapleAOSP/${DEVICE}
            ZIP_FORMAT=MapleAOSP*.zip ;;
         "pn")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/PN
            ZIP_MOVE=${HOME}/Completed/Zips/ROMs/PureNexus/${DEVICE}
            ZIP_FORMAT=pure_nexus_${DEVICE}-7*.zip ;;
         "pn-mod")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/PN-Mod
            ZIP_MOVE=${HOME}/Completed/Zips/ROMs/PureNexusMod/${DEVICE}
            ZIP_FORMAT=pnmod_nexus_${DEVICE}-*.zip ;;
         "saosp")
            SOURCE_DIR=${ANDROID_DIR}/ROMs/SAOSP
            ZIP_MOVE=${HOME}/Completed/Zips/ROMs/SAOSP/${DEVICE}
            ZIP_FORMAT=saosp_${DEVICE}*.zip ;;
      esac
   fi

   OUT_DIR=${SOURCE_DIR}/out/target/product/${DEVICE}
   THREADS_FLAG=-j$( grep -c ^processor /proc/cpuinfo )


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

   repo sync --force-sync ${THREADS_FLAG}



   # Setup the build environment
   echoText "SETTING UP BUILD ENVIRONMENT"; newLine

   source build/envsetup.sh



   # Prepare device
   echoText "PREPARING $( echo ${DEVICE} | awk '{print toupper($0)}' )"; newLine

   # We have different options for different ROMs (not all use breakfast)
   case "${ROM}" in
      "maple")
         lunch maple_${DEVICE}-userdebug ;;
      "saosp")
         lunch saosp_${DEVICE}-user ;;
      "aosip")
         lunch aosip_${DEVICE}-userdebug ;;
      *)
         breakfast ${DEVICE} ;;
   esac



   # Clean up from previous compilation
   echoText "CLEANING UP OUT DIRECTORY"; newLine

   make clobber



   # Start building
   echoText "MAKING ZIP FILE"; newLine

   NOW=$( TZ=MST date +"%Y-%m-%d-%S" )

   # We have different options for different ROMs (not all use mka or bacon)
   case "${ROM}" in
      "saosp")
         time make otapackage ${THREADS_FLAG} 2>&1 | tee ${LOGDIR}/Compilation/${ROM}_${DEVICE}-${NOW}.log ;;
      "aosip")
         time make kronic ${THREADS_FLAG} 2>&1 | tee ${LOGDIR}/Compilation/${ROM}_${DEVICE}-${NOW}.log ;;
      *)
         time mka bacon 2>&1 | tee ${LOGDIR}/Compilation/${ROM}_${DEVICE}-${NOW}.log ;;
   esac



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



   # Add line to compile log in the following format:
   # DATE: BASH_SOURCE (EXTRA STUFF)
   case ${PERSONAL} in
      "true")
         echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} me" >> ${LOG} ;;
      *)
         echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${ROM} ${DEVICE}" >> ${LOG} ;;
   esac

   # BUILD RESULT IN X MINUTES AND Y SECONDS
   echo -e "${BUILD_RESULT_STRING} IN $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )" >> ${LOG}

   # FILE LOCATION: PATH (only done if there was a file compiled succesfully)
   if [[ ${SUCCESS} = true ]]; then
      echo -e "FILE LOCATION: $( ls ${ZIP_MOVE}/${ZIP_FORMAT} )" >> ${LOG}
   fi

   echo -e "\a"
}

# If the first parameter to the rom.sh script is "normal" or "release" followed by the rom type, we are running four or seven builds for the devices we support
if [[ "${1}" == "normal" || "${1}" == "release" ]]; then
   case "${1}" in
      "normal")
         DEVICES="angler shamu bullhead hammerhead" ;;
      "release")
         DEVICES="angler shamu bullhead hammerhead flo deb flounder" ;;
   esac

   for DEVICE in ${DEVICES}; do
      compile ${2} ${DEVICE}
   done

   cd ${HOME}
   cat ${LOG}
# Otherwise, it is just one build with the parameters given
else
   compile ${1} ${2}
fi
