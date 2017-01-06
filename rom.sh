#!/bin/bash
#
# ROM compilation script
#
# Copyright (C) 2016 Nathan Chancellor
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>


###########
#         #
#  USAGE  #
#         #
###########

# PURPOSE: Build an Android ROM from source
# USAGE:
# $ rom.sh me
# $ rom.sh <flash|pn|du|abc|krexus|aosip> <shamu|angler|bullhead|hammerhead>


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

# UNSETS VARIABLES POTENTIALLY USED IN SCRIPT
function unsetvars() {
   unset ROM_BUILD_TYPE
   unset SUBSTRATUM
   unset LOCALVERSION
   unset BUILD_TAG
   unset SYNC
   unset PERSONAL
   unset SUCCESS
}

# CHECKS IF MKA EXISTS
function make_command() {
   while [[ $# -ge 1 ]]; do
      PARAMS+="${1} "

      shift
   done

   MKA=$( command -v mka )
   if [[ -n ${MKA} ]]; then
      mka ${PARAMS}
   else
      make -j$( grep -c ^processor /proc/cpuinfo ) ${PARAMS}
   fi

   unset PARAMS
   unset MKA
}

################
#              #
#  PARAMETERS  #
#              #
################

unsetvars

while [[ $# -ge 1 ]]; do
   case "${1}" in
      "me")
         ROM=flash
         DEVICE=angler
         export LOCALVERSION=-$( TZ=MST date +%Y%m%d ) ;;
      "shamu"|"angler"|"bullhead"|"hammerhead")
         DEVICE=${1} ;;
      "abc"|"aosip"|"du"|"flash"|"krexus"|"pn")
         ROM=${1} ;;
      "nosync")
         SYNC=false ;;
      "nosubs")
         export SUBSTRATUM=false ;;
      "type")
         shift
         if [[ $# -ge 1 ]]; then
            export BUILD_TAG=${1}
         else
            echo "Please specify a build type!" && exit
         fi ;;
      *)
         echo "Invalid parameter detected!" && exit ;;
   esac

   shift
done

# PARAMETER VERIFICATION
if [[ -z ${DEVICE} || -z ${ROM} ]]; then
   echo "You did not specify a necessary parameter (either ROM, device, or both). Please re-run the script with the necessary parameters!" && exit
fi

###############
#             #
#  VARIABLES  #
#             #
###############

# ANDROID_DIR: Directory that holds all of the Android files (currently my home directory)
# OUT_DIR: Directory that holds the compiled ROM files
# SOURCE_DIR: Directory that holds the ROM source
# ZIP_MOVE: Directory to hold completed ROM zips
# ZIP_FORMAT: The format of the zip file in the out directory for moving to ZIP_MOVE
ANDROID_DIR=${HOME}
ZIP_MOVE_PARENT=${HOME}/Web/.superhidden/ROMs

# Otherwise, define them for our various ROMs
case "${ROM}" in
   "abc")
      SOURCE_DIR=${ANDROID_DIR}/ROMs/ABC
      ZIP_MOVE=${ZIP_MOVE_PARENT}/ABC/${DEVICE}
      ZIP_FORMAT=ABCrom_${DEVICE}-*.zip ;;
   "aosip")
      SOURCE_DIR=${ANDROID_DIR}/ROMs/AOSiP
      ZIP_MOVE=${ZIP_MOVE_PARENT}/AOSiP/${DEVICE}
      ZIP_FORMAT=AOSiP-*-${DEVICE}-*.zip ;;
   "du")
      SOURCE_DIR=${ANDROID_DIR}/ROMs/DU
      ZIP_MOVE=${ZIP_MOVE_PARENT}/DirtyUnicorns/${DEVICE}
      ZIP_FORMAT=DU_${DEVICE}_*.zip ;;
   "flash")
      SOURCE_DIR=${ANDROID_DIR}/ROMs/Flash
      ZIP_MOVE=${ZIP_MOVE_PARENT}/Flash/${DEVICE}
      ZIP_FORMAT=flash_rom_${DEVICE}-*.zip ;;
   "krexus")
      SOURCE_DIR=${ANDROID_DIR}/ROMs/Krexus
      ZIP_MOVE=${ZIP_MOVE_PARENT}/Krexus/${DEVICE}
      ZIP_FORMAT=*krexus*${DEVICE}.zip ;;
   "pn")
      SOURCE_DIR=${ANDROID_DIR}/ROMs/PN
      ZIP_MOVE=${ZIP_MOVE_PARENT}/PureNexus/${DEVICE}
      ZIP_FORMAT=purenexus_${DEVICE}-7*.zip ;;
esac

OUT_DIR=${SOURCE_DIR}/out/target/product/${DEVICE}


#######################
# START TRACKING TIME #
#######################

clear
START=$( TZ=MST date +%s )


###########################
# MOVE INTO SOURCE FOLDER #
###########################

cd ${SOURCE_DIR}


#############
# REPO SYNC #
#############

if [[ ${SYNC} != false ]]; then
   echoText "SYNCING LATEST SOURCES"; newLine

   repo sync --force-sync ${THREADS_FLAG}
fi


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

echoText "PREPARING $( echo ${DEVICE} | awk '{print toupper($0)}' )"; newLine

# NOT ALL ROMS USE BREAKFAST
case "${ROM}" in
   "aosip")
      lunch aosip_${DEVICE}-userdebug ;;
   "krexus")
      lunch krexus_${DEVICE}-user ;;
   *)
      breakfast ${DEVICE} ;;
esac


############
# CLEAN UP #
############

echoText "CLEANING UP OUT DIRECTORY"; newLine

make_command clobber

##################
# START BUILDING #
##################

if [[ ${ROM} == "flash" ]]; then
   echo -e ${RED}
   echo -e "========================================================================"; newLine
   echo -e "  ___________________________________  __   _____________________  ___  "
   echo -e "  ___  ____/__  /___    |_  ___/__  / / /   ___  __ \_  __ \__   |/  /  "
   echo -e "  __  /_   __  / __  /| |____ \__  /_/ /    __  /_/ /  / / /_  /|_/ /   "
   echo -e "  _  __/   _  /___  ___ |___/ /_  __  /     _  _, _// /_/ /_  /  / /    "
   echo -e "  /_/      /_____/_/  |_/____/ /_/ /_/      /_/ |_| \____/ /_/  /_/     "; newLine
   echo -e "========================================================================"; newLine
   echo -e ${RESTORE}
   sleep 5
else
   echoText "MAKING ZIP FILE"; newLine
fi

NOW=$( TZ=MST date +"%Y-%m-%d-%S" )

# NOT ALL ROMS USE BACON
case "${ROM}" in
   "aosip")
      time make_command kronic ;;
   "krexus")
      time make_command otapackage ;;
   *)
      time make_command bacon ;;
esac


###################
# IF ROM COMPILED #
###################

# THERE WILL BE A ZIP IN THE OUT FOLDER IN THE ZIP FORMAT
if [[ $( ls ${OUT_DIR}/${ZIP_FORMAT} 2>/dev/null | wc -l ) != "0" ]]; then
   # MAKE BUILD RESULT STRING REFLECT SUCCESSFUL COMPILATION
   BUILD_RESULT_STRING="BUILD SUCCESSFUL"
   SUCCESS=true


   ##################
   # ZIP_MOVE LOGIC #
   ##################

   # MAKE ZIP_MOVE IF IT DOESN'T EXIST OR CLEAN IT IF IT DOES
   if [[ ! -d "${ZIP_MOVE}" ]]; then
      newLine; echoText "MAKING ZIP_MOVE DIRECTORY"

      mkdir -p "${ZIP_MOVE}"
   else
      newLine; echoText "CLEANING ZIP_MOVE DIRECTORY"; newLine

      rm -vrf "${ZIP_MOVE}"/*${ZIP_FORMAT}*
   fi


   ####################
   # MOVING ROM FILES #
   ####################

   newLine; echoText "MOVING FILES TO ZIP_MOVE DIRECTORY"; newLine

   mv -v ${OUT_DIR}/*${ZIP_FORMAT}* "${ZIP_MOVE}"


###################
# IF BUILD FAILED #
###################

else
   BUILD_RESULT_STRING="BUILD FAILED"
   SUCCESS=false
fi



# DEACTIVATE VIRTUALENV IF WE ARE ON ARCH
if [[ -f /etc/arch-release ]]; then
   echoText "EXITING VIRTUAL ENV"
   deactivate
fi



##############
# SCRIPT END #
##############

END=$( TZ=MST date +%s )
newLine; echoText "${BUILD_RESULT_STRING}!"


######################
# ENDING INFORMATION #
######################

# IF THE BUILD WAS SUCCESSFUL, PRINT FILE LOCATION, AND SIZE
if [[ ${SUCCESS} = true ]]; then
   echo -e ${RED}"FILE LOCATION: $( ls ${ZIP_MOVE}/${ZIP_FORMAT} )"
   echo -e "SIZE: $( du -h ${ZIP_MOVE}/${ZIP_FORMAT} | awk '{print $1}'  )"${RESTORE}
fi

# PRINT THE TIME THE SCRIPT FINISHED
# AND HOW LONG IT TOOK REGARDLESS OF SUCCESS
echo -e ${RED}"TIME FINISHED: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
echo -e ${RED}"DURATION: $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )"${RESTORE}; newLine



##################
# LOG GENERATION #
##################

# DATE: BASH_SOURCE (PARAMETERS)
case ${PERSONAL} in
   "true")
      echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} me" >> ${LOG} ;;
   *)
      echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${ROM} ${DEVICE}" >> ${LOG} ;;
esac

# BUILD <SUCCESSFUL|FAILED> IN # MINUTES AND # SECONDS
echo -e "${BUILD_RESULT_STRING} IN $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )" >> ${LOG}

# ONLY ADD A LINE ABOUT FILE LOCATION IF SCRIPT COMPLETED SUCCESSFULLY
if [[ ${SUCCESS} = true ]]; then
   # FILE LOCATION: <PATH>
   echo -e "FILE LOCATION: $( ls ${ZIP_MOVE}/${ZIP_FORMAT} )" >> ${LOG}
fi


########################
# ALERT FOR SCRIPT END #
########################

echo -e "\a" && cd ${HOME}

# UNSET EXPORTS
unsetvars
