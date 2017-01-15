#!/bin/bash
#
# Substratum compilation and upload script
#
# Copyright (C) 2016-2017 Nathan Chancellor
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

# PURPOSE: Build a Substratum APK
# USAGE: $ bash substratum.sh <update|build|both>


############
#          #
#  COLORS  #
#          #
############

RED="\033[01;31m"
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

while [[ $# -ge 1 ]]; do
   case "${1}" in
      "build"|"both"|"update")
         PARAM=${1} ;;
      *)
         echo "Invalid parameter" && exit ;;
   esac

   shift
done

if [[ -z ${PARAM} ]]; then
   echo "You did not specify a necessary parameter. Falling back to building only"
   PARAM=build
fi


##################
#                #
#  SCRIPT START  #
#                #
##################

# START TIME TRACKING
START=$( TZ=MST date +%s )

# SET VARIABLES
SOURCE_DIR=${HOME}/Repos/substratum
OUT_DIR=${SOURCE_DIR}/app/build/outputs/apk
APK_FORMAT=substratum*.apk
APK_MOVE=${HOME}/Web/.superhidden/APKs

# UNSET JAVA_HOME SO GRADLE CAN PROPERLY SET IT
unset JAVA_HOME

# GET CURRENT DIR FOR later
CURRENT_DIR=$( pwd )

# UPDATE REPO IF REQUESTED
if [[ "${PARAM}" == "update" || "${PARAM}" == "both" ]]; then
   cd ${SOURCE_DIR}
   git pull upstream dev --rebase && git push --force
fi

if [[ "${PARAM}" == "build" || "${PARAM}" == "both" ]]; then
   # CLEAN PREVIOUS BUILD
   ./gradlew clean

   # MAKE NEW APK
   ./gradlew assembleDebug

   # IF THE APK WAS FOUND, MOVE IT
   if [[ $( ls ${OUT_DIR}/${APK_FORMAT} 2>/dev/null | wc -l ) != "0" ]]; then
      RESULT_STRING="BUILD SUCCESSFUL"
      if [[ -d ${APK_MOVE} ]]; then
         rm -vrf ${APK_MOVE}/${APK_FORMAT}
      else
         mkdir -p ${APK_MOVE}
      fi
      cp -v ${OUT_DIR}/${APK_FORMAT} ${APK_MOVE}

   # OTHERWISE, REPORT IT!
   else
      RESULT_STRING="BUILD FAILED"
   fi

   # END TIME TRACKING
   END=$( TZ=MST date +%s )

   # PRINT RESULT
   # IF THE BUILD WAS SUCCESSFUL, PRINT FILE LOCATION AND SIZE
   newLine; echoText "${RESULT_STRING}!"
   if [[ ${RESULT_STRING} == "BUILD SUCCESSFUL" ]]; then
     echo -e ${RED}"FILE LOCATION: $( ls "${APK_MOVE}"/${APK_FORMAT} )"
     echo -e "SIZE: $( du -h "${APK_MOVE}"/${APK_FORMAT} | awk '{print $1}' )"${RESTORE}
   fi

   # PRINT HOW LONG IT TOOK REGARDLESS OF SUCCESS
   echo -e ${RED}"DURATION: $( echo $((${END}-${START})) | awk '{print int($1/60)" MINUTES AND "int($1%60)" SECONDS"}' )"${RESTORE}; newLine
fi

# MOVE BACK TO ORIGINAL DIRECTORY
cd ${CURRENT_DIR}
