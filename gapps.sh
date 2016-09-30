#!/bin/bash

# -----
# Usage
# -----
# $ . gapps.sh banks
# $ . gapps.sh open <super|stock|full|mini|micro|nano|pico>



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



# ------------------------
# Parameters and variables
# ------------------------

# Unassign success flags
SUCCESS=false

# Head Android directory
ANDROID_DIR=${HOME}

# GApps completed zip directory
ZIP_MOVE=${HOME}/Web/.hidden/GApps


# If there is no first paramter, get it from the user
if [[ -z ${1} ]]; then
   echo "GApps selection"
   echo "   1. Banks"
   echo "   2. Open"
   read -p "Which GApps would you like to build? " TYPE_NUM

   case ${TYPE_NUM} in
      "1")
         TYPE=banks ;;
      "2")
         TYPE=open ;;
      *)
         echo "Invalid selection, please run the script again" && return
   esac

else
   TYPE=${1}
fi


# Type logic
case ${TYPE} in
   "banks")
      SOURCE_DIR=${ANDROID_DIR}/GApps/Banks
      ZIP_BEG=banks
      BRANCH=n ;;
   "open")
      SOURCE_DIR=${ANDROID_DIR}/GApps/Open
      ZIP_BEG=open
      BRANCH=master

      if [[ -z ${2} ]]; then
         echo "You have chosen Open GApps!"

         VERSIONS="Super Stock Full Mini Micro Nano Pico"
         COUNTER=1

         for CURRENT in ${VERSIONS}; do
            echo "   ${COUNTER}. ${CURRENT}"
            (( COUNTER++ ))
         done

         read -p "Which version of Open GApps would you like to build? " VERSION_NUM

         case ${VERSION_NUM} in
            "1")
               VERSION=super ;;
            "2")
               VERSION=stock ;;
            "3")
               VERSION=full ;;
            "4")
               VERSION=mini ;;
            "5")
               VERSION=micro ;;
            "6")
               VERSION=nano ;;
            "7")
               VERSION=pico ;;
            *)
               echo "Invalid selection, please run the script again" && return
         esac

      else
         VERSION=${2}
      fi ;;
esac



# ---------
# Variables
# ---------


# Export the LOG variable for other files to use (I currently handle this via .bashrc)
# export LOG_DIR=${ANDROID_DIR}/Logs
# export LOG=${LOG_DIR}/compile_log_$( TZ=MST date +%m_%d_%y ).log



# Clear the terminal
clear



# Start tracking time
START=$( TZ=MST date +%s )



# Go into repo folder
cd ${SOURCE_DIR}



# Clean up repo
echoText "CLEANING UP REPO"

git reset --hard origin/${BRANCH}
git clean -f -d -x



# Get new changes
echoText "UPDATING REPO"

git pull
if [[ "${TYPE}" == "open" ]]; then
   ./download_sources.sh --shallow arm64
fi



# Make GApps
echoText "BUILDING $( echo ${TYPE} | awk '{print toupper($0)}' ) GAPPS"

case "${TYPE}" in
   "banks")
      . mkgapps.sh ;;
   "open")
      make arm64-24-${VERSION} ;;
esac



# If the above was successful
if [[ `ls ${SOURCE_DIR}/out/${ZIP_BEG}*.zip 2>/dev/null | wc -l` != "0" ]]; then
   BUILD_RESULT_STRING="BUILD SUCCESSFUL"
   SUCCESS=true

   # If ZIP_MOVE doesn't exist, make it; otherwise, clean it
   if [[ ! -d ${ZIP_MOVE} ]]; then
      mkdir -p ${ZIP_MOVE}
   else
      # Remove current GApps and move the new ones in their place
      rm -rf ${ZIP_MOVE}/${ZIP_BEG}*.zip
   fi

   mv -v ${SOURCE_DIR}/out/${ZIP_BEG}*.zip ${ZIP_MOVE}

# If the build failed, add a variable
else
   BUILD_RESULT_STRING="BUILD FAILED"
   SUCCESS=false

fi



# Stop tracking time
END=$( TZ=MST date +%s )



# Go home and we're done!
cd ${HOME}



# Stop tracking time
END=$( TZ=MST date +%s )
newLine; echoText "${BUILD_RESULT_STRING}!"

# Print the zip location and its size if the script was successful
if [[ ${SUCCESS} = true ]]; then
   echo -e ${RED}"ZIP: $( ls ${ZIP_MOVE}/${ZIP_BEG}*.zip )"
   echo -e "SIZE: $( du -h ${ZIP_MOVE}/${ZIP_BEG}*.zip | awk '{print $1}' )"${RST}
fi
# Print the time the script finished and how long the script ran for regardless of success
echo -e ${RED}"TIME FINISHED: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
echo -e ${RED}"DURATION: $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )"${RST}; newLine

# Add line to compile log
echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${TYPE}" >> ${LOG}
echo -e "${BUILD_RESULT_STRING} IN $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')" >> ${LOG}
if [[ ${SUCCESS} = true ]]; then
   echo -e "FILE LOCATION: $( ls ${ZIP_MOVE}/${ZIP_BEG}*.zip )" >> ${LOG}
fi
echo -e "\a"
