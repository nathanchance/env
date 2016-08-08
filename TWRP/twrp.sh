#!/bin/bash


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


# Compiliation function
function compile() {
   # Parameters
   DEVICE=${1}


   # Directories
   SOURCEDIR=${HOME}/TWRP
   OUTDIR=${SOURCEDIR}/out/target/product/${DEVICE}
   UPLOADDIR=${HOME}/shared/TWRP


   # File names
   COMPFILE=recovery.img
   UPLDFILE=twrp-${DEVICE}-$( date +%m%d%Y ).img
   FILEFORMAT=twrp-${DEVICE}*


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


   # Setup the build environment
   echoText "SETTING UP BUILD ENVIRONMENT"; newLine

   . build/envsetup.sh


   # Prepare device
   newLine; echoText "PREPARING $( echo ${DEVICE} | awk '{print toupper($0)}' )"

   lunch omni_${DEVICE}-eng


   # Clean up
   echoText "CLEANING UP OUT DIRECTORY"; newLine

   mka clobber


   # Start building
   newLine; echoText "MAKING TWRP"; newLine
   NOW=$( date +"%Y-%m-%d-%S" )
   time mka recoveryimage 2>&1 | tee ${LOGDIR}/Compilation/twrp_${DEVICE}-${NOW}.log


   # If the compilation was successful, there will be a file in the format above in the out directory
   if [[ $( ls ${OUTDIR}/${COMPFILE} 2>/dev/null | wc -l ) != "0" ]]; then
      # Make the build result string show success
      BUILD_RESULT_STRING="BUILD SUCCESSFUL"



      # If the upload directory doesn't exist, make it; otherwise, remove existing files in UPLOADDIR
      if [[ ! -d "${UPLOADDIR}" ]]; then
         newLine; echoText "MAKING UPLOAD DIRECTORY"

         mkdir -p "${UPLOADDIR}"
      else
         newLine; echoText "CLEANING UPLOAD DIRECTORY"; newLine

         rm -vrf "${UPLOADDIR}"/*${FILEFORMAT}*
      fi


      # Copy new files to UPLOADDIR
      newLine; echoText "MOVING FILE TO UPLOAD DIRECTORY"; newLine

      mv -v ${OUTDIR}/${COMPFILE} "${UPLOADDIR}"/${UPLDFILE}


      # Upload the files
      newLine; echoText "UPLOADING FILE"; newLine

      . ${HOME}/upload.sh


      # Clean up out directory to free up space
      newLine; echoText "CLEANING UP OUT DIRECTORY"; newLine

      mka clobber


      # Go back home
      newLine; echoText "GOING HOME"

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

   # Add line to compilation log
   echo -e "$( date +%H:%M:%S ): ${BASH_SOURCE} ${DEVICE}" >> ${LOG}
   echo -e "${BUILD_RESULT_STRING} IN $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )\n" >> ${LOG}

   echo -e "\a"
}


# If the first parameter to the twrp.sh script is "all", we are running five builds for the devices we support; otherwise, it is just a device specific build
if [[ "${1}" == "all" ]]; then
   DEVICES="angler shamu bullhead hammerhead mako"

   for DEVICE in ${DEVICES}; do
      compile ${DEVICE}
   done

   cd ${HOME}
   cat ${LOG}
else
   compile ${1}
fi
