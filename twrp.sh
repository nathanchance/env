#!/bin/bash
#
# TWRP compilation script
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

# $ twrp.sh <device>


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

# UNASSIGN FLAGS AND RESET ROM_BUILD_TYPE
SUCCESS=false

while [[ $# -ge 1 ]]; do
   case "${1}" in
      "shamu"|"angler"|"bullhead"|"hammerhead")
         DEVICE=${1} ;;
      *)
         echo "Invalid parameter detected!" && exit ;;
   esac

   shift
done

# PARAMETER VERIFICATION
if [[ -z ${DEVICE} ]]; then
   echo "You did not specify a necessary parameter (the device to compile for). Please re-run the script with the necessary parameters!" && exit
fi


###############
#             #
#  VARIABLES  #
#             #
###############

# DIRECTORIES
SOURCE_DIR=${HOME}/ROMs/Omni
OUT_DIR=${SOURCE_DIR}/out/target/product/${DEVICE}
IMG_MOVE=${HOME}/Web/.superhidden/TWRP

# FILE NAMES
COMP_FILE=recovery.img
UPLD_FILE=twrp-${DEVICE}-$( TZ=MST date +%m%d%Y ).img
FILE_FORMAT=twrp-${DEVICE}*


################
# START SCRIPT #
################

clear

# EXPORT JAVA8
export EXPERIMENTAL_USE_JAVA8=true


#######################
# START TRACKING TIME #
#######################

START=$( TZ=MST date +%s )


###########################
# MOVE INTO SOURCE FOLDER #
###########################

cd ${SOURCE_DIR}


#############
# REPO SYNC #
#############

echoText "SYNCING LATEST SOURCES"; newLine

repo sync --force-sync -j$(grep -c ^processor /proc/cpuinfo)


###########################
# SETUP BUILD ENVIRONMENT #
###########################

echoText "SETTING UP BUILD ENVIRONMENT"; newLine

# CHECK AND SEE IF WE ARE ON ARCH; IF SO, ACTIVARE A VIRTUAL ENVIRONMENT FOR PROPER PYTHON SUPPORT
if [[ -f /etc/arch-release ]]; then
   virtualenv2 venv
   source venv/bin/activate
fi

source build/envsetup.sh


##################
# PREPARE DEVICE #
##################

newLine; echoText "PREPARING $( echo ${DEVICE} | awk '{print toupper($0)}' )"

lunch omni_${DEVICE}-eng


############
# CLEAN UP #
############

echoText "CLEANING UP OUT DIRECTORY"; newLine

mka clobber


##################
# START BUILDING #
##################

newLine; echoText "MAKING TWRP"; newLine
NOW=$( TZ=MST date +"%Y-%m-%d-%S" )
time mka recoveryimage 2>&1 | tee ${LOGDIR}/Compilation/twrp_${DEVICE}-${NOW}.log


####################
# IF TWRP COMPILED #
####################

# THERE WILL BE A FILE IN THE OUT FOLDER IN THE ABOVE FORMAT
if [[ $( ls ${OUT_DIR}/${COMP_FILE} 2>/dev/null | wc -l ) != "0" ]]; then
  # MAKE BUILD RESULT STRING REFLECT SUCCESSFUL COMPILATION
  BUILD_RESULT_STRING="BUILD SUCCESSFUL"
  SUCCESS=true


  ##################
  # IMG_MOVE LOGIC #
  ##################

  # MAKE IMG_MOVE IF IT DOESN'T EXIST OR CLEAN IT IF IT DOES
  if [[ ! -d "${IMG_MOVE}" ]]; then
     newLine; echoText "MAKING UPLOAD DIRECTORY"

     mkdir -p "${IMG_MOVE}"
  else
     newLine; echoText "CLEANING UPLOAD DIRECTORY"; newLine

     rm -vrf "${IMG_MOVE}"/*${FILE_FORMAT}*
  fi


  ####################
  # MOVING TWRP FILE #
  ####################

  newLine; echoText "MOVING FILE TO UPLOAD DIRECTORY"; newLine

  mv -v ${OUT_DIR}/${COMP_FILE} "${IMG_MOVE}"/${UPLD_FILE}


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

# DEACTIVATE VIRTUALENV IF WE ARE ON ARCH
if [[ -f /etc/arch-release ]]; then
   echoText "EXITING VIRTUAL ENV"
   deactivate
fi

END=$( TZ=MST date +%s )
newLine; echoText "${BUILD_RESULT_STRING}!"


######################
# ENDING INFORMATION #
######################

# IF THE BUILD WAS SUCCESSFUL, PRINT FILE LOCATION AND SIZE
if [[ ${SUCCESS} = true ]]; then
  echo -e ${RED}"FILE LOCATION: $( ls "${IMG_MOVE}"/${UPLD_FILE} )"
  echo -e "SIZE: $( du -h "${IMG_MOVE}"/${UPLD_FILE} | awk '{print $1}' )"${RESTORE}
fi

# PRINT THE TIME THE SCRIPT FINISHED
# AND HOW LONG IT TOOK REGARDLESS OF SUCCESS
echo -e ${RED}"TIME FINISHED: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
echo -e ${RED}"DURATION: $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )"${RESTORE}; newLine


##################
# LOG GENERATION #
##################

# DATE: BASH_SOURCE (PARAMETERS)
echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${DEVICE}" >> ${LOG}

# BUILD <SUCCESSFUL|FAILED> IN # MINUTES AND # SECONDS
echo -e "${BUILD_RESULT_STRING} IN $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )" >> ${LOG}

# ONLY ADD A LINE ABOUT FILE LOCATION IF SCRIPT COMPLETED SUCCESSFULLY
if [[ ${SUCCESS} = true ]]; then
  # FILE LOCATION: <PATH>
  echo -e "FILE LOCATION: $( ls "${IMG_MOVE}"/${UPLD_FILE} )" >> ${LOG}
fi


########################
# ALERT FOR SCRIPT END #
########################

echo -e "\a" && cd ${HOME}
