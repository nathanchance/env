#!/bin/bash
#
# GApps compilation script for the Nexus 6P
#
# Copyright (C) 2016 Nathan Chancellor
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


###########
#         #
#  USAGE  #
#         #
###########

# $ gapps.sh banks
# $ gapps.sh open <super|stock|full|mini|micro|nano|pico>


############
#          #
#  COLORS  #
#          #
############

RED="\033[01;31m"
BLINK_RED="\033[05;31m"
RESTORE="\033[0m"


###############
#             #
#  FUNCTIONS  #
#             #
###############

# PRINTS A FORMATTED HEADER TO POINT OUT WHAT IS BEING DONE TO THE USER
function echoText() {
   echo -e ${RED}
   echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
   echo -e "==  ${1}  =="
   echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
   echo -e ${RESTORE}
}


# CREATES A NEW LINE IN TERMINAL
function newLine() {
   echo -e ""
}


################
#              #
#  PARAMETERS  #
#              #
################

# RESET SUCCESS FLAG
SUCCESS=false

while [[ $# -ge 1 ]]; do
   case "${1}" in
      "open"|"banks")
         TYPE=${1} ;;
      "super"|"stock"|"full"|"mini"|"micro"|"nano"|"pico")
         VERSION=${1} ;;
      *)
         echo "Invalid parameter" && exit ;;
   esac

   shift
done

if [[ -z ${TYPE} ]] || [[ ${TYPE} == "open" && -z ${VERSION} ]]; then
   echo "You did not specify a necessary parameter (either type of GApps or type of Open GApps). Please re-run the script with the necessary parameters!" && exit
fi

###############
#             #
#  VARIABLES  #
#             #
###############

ANDROID_DIR=${HOME}
ZIP_MOVE=${HOME}/Web/.hidden/GApps

# Type logic
case ${TYPE} in
   "banks")
      SOURCE_DIR=${ANDROID_DIR}/GApps/Banks
      ZIP_FORMAT=banks*.zip
      BRANCH=n ;;
   "open")
      SOURCE_DIR=${ANDROID_DIR}/GApps/Open
      ZIP_FORMAT=open*${VERSION}*.zip
      BRANCH=master ;;
esac

################
# SCRIPT START #
################

clear



# SET THE START OF THE SCRIPT
START=$( TZ=MST date +%s )


# MOVE INTO SOURCE FOLDER
cd ${SOURCE_DIR}


if [[ "${TYPE}" == "banks" ]]; then
   ############
   # CLEAN UP #
   ############

   echoText "CLEANING UP REPO"

   git reset --hard origin/${BRANCH}
   git clean -f -d -x
fi


#####################
# FETCH NEW CHANGES #
#####################

echoText "UPDATING REPO"

git pull
if [[ "${TYPE}" == "open" ]]; then
   ./download_sources.sh --shallow arm64
fi


##############
# MAKE GAPPS #
##############

echoText "BUILDING $( echo ${TYPE} | awk '{print toupper($0)}' ) GAPPS"

case "${TYPE}" in
   "banks")
      source mkgapps.sh ;;
   "open")
      make arm64-24-${VERSION} ;;
esac


#####################
# IF GAPPS COMPILED #
#####################

# THERE WILL BE A ZIP IN THE OUT FOLDER IN THE ZIP FORMAT
if [[ $( ls ${SOURCE_DIR}/out/${ZIP_FORMAT} 2>/dev/null | wc -l ) != "0" ]]; then
   # MAKE BUILD RESULT STRING REFLECT SUCCESSFUL COMPILATION
   BUILD_RESULT_STRING="BUILD SUCCESSFUL"
   SUCCESS=true


   ##################
   # ZIP_MOVE LOGIC #
   ##################

   # MAKE ZIP_MOVE IF IT DOESN'T EXIST OR CLEAN IT IF IT DOES
   if [[ ! -d ${ZIP_MOVE} ]]; then
      mkdir -p ${ZIP_MOVE}
   else
      rm -rf ${ZIP_MOVE}/${ZIP_FORMAT}
   fi


   ######################
   # MOVING GAPPS FILES #
   ######################

   newLine; echoText "MOVING FILES TO ZIP_MOVE DIRECTORY"; newLine

   mv -v ${SOURCE_DIR}/out/${ZIP_FORMAT} ${ZIP_MOVE}


###################
# IF BUILD FAILED #
###################

else
   BUILD_RESULT_STRING="BUILD FAILED"
   SUCCESS=false

fi


##############
# SCRIPT END #
##############

END=$( TZ=MST date +%s )
newLine; echoText "${BUILD_RESULT_STRING}!"


######################
# ENDING INFORMATION #
######################

# IF THE BUILD WAS SUCCESSFUL, PRINT FILE LOCATION AND SIZE
if [[ ${SUCCESS} = true ]]; then
   echo -e ${RED}"FILE LOCATION: $( ls ${ZIP_MOVE}/${ZIP_FORMAT} )"
   echo -e "SIZE: $( du -h ${ZIP_MOVE}/${ZIP_FORMAT} | awk '{print $1}' )"${RESTORE}
fi

# PRINT THE TIME THE SCRIPT FINISHED
# AND HOW LONG IT TOOK REGARDLESS OF SUCCESS
echo -e ${RED}"TIME FINISHED: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
echo -e ${RED}"DURATION: $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )"${RESTORE}; newLine


##################
# LOG GENERATION #
##################

# DATE: BASH_SOURCE (PARAMETERS)
echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${TYPE}" >> ${LOG}

# BUILD <SUCCESSFUL|FAILED> IN # MINUTES AND # SECONDS
echo -e "${BUILD_RESULT_STRING} IN $(echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}')" >> ${LOG}

# ONLY ADD A LINE ABOUT FILE LOCATION IF SCRIPT COMPLETED SUCCESSFULLY
if [[ ${SUCCESS} = true ]]; then
   # FILE LOCATION: <PATH>
   echo -e "FILE LOCATION: $( ls ${ZIP_MOVE}/${ZIP_FORMAT} )" >> ${LOG}
fi


########################
# ALERT FOR SCRIPT END #
########################

echo -e "\a" && cd ${HOME}
