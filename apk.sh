#!/usr/bin/env bash
#
# APK build script
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

# PURPOSE: Build a specified APK
# USAGE: $ bash apk.sh -h


###############
#             #
#  FUNCTIONS  #
#             #
###############

# SOURCE OUR UNIVERSAL FUNCTIONS SCRIPT
source $( dirname ${BASH_SOURCE} )/funcs.sh

# CURRENTLY I BUILD ALL APKS ON MY PERSONAL MACHINE, NOT MY SERVER
if [[ -f /etc/arch-release ]]; then
    reportError "Wrong window! ;)" && exit
fi

# PRINT A HELP MENU IF REQUESTED
function help_menu() {
    echo -e ""
    echo -e "${BOLD}OVERVIEW:${RST} Builds and pushes the specified APK\n"
    echo -e "${BOLD}USAGE:${RST} bash ${0} <apk> <options>\n"
    echo -e "${BOLD}EXAMPLE:${RST} bash ${0} substratum build\n"
    echo -e "${BOLD}REQUIRED PARAMETERS:${RST}"
    echo -e "   apk:       magisk | spectrum | substratum\n"
    echo -e "${BOLD}OPTIONAL PARAMETERS:${RST}"
    echo -e "   build:      update the source and builds the specified APK"
    echo -e "   install:    builds and pushes the APK to a local device"
    echo -e "No options will fallback to build\n"
    exit
}


################
#              #
#  PARAMETERS  #
#              #
################

while [[ $# -ge 1 ]]; do
    case "${1}" in
        "magisk"|"spectrum"|"substratum")
            APK=${1} ;;
        "build"|"install")
            ACTION=${1} ;;
        "-h"|"--help")
            help_menu ;;
        *)
            reportError "Invalid parameter" && exit ;;
    esac

    shift
done

if [[ -z ${APK} ]]; then
    reportError "No specified APK!" -c
    help_menu
    exit
fi

if [[ -z ${ACTION} ]]; then
    reportWarning "You did not specify the required action! Falling back to building only" -c
    ACTION=build
fi


##################
#                #
#  SCRIPT START  #
#                #
##################

# START TIME TRACKING
START=$( TZ=MST date +%s )

# SET VARIABLES
case ${APK} in
    "magisk")
        SOURCE_DIR=${HOME}/Documents/Repos/MagiskManager
        APK_NAME=MagiskManager ;;
    "substratum")
        SOURCE_DIR=${HOME}/Documents/Repos/Substratum/flash
        APK_NAME=Substratum ;;
    "spectrum")
        SOURCE_DIR=${HOME}/Documents/Repos/Spectrum
        APK_NAME=Spectrum ;;
esac
OUT_DIR=${SOURCE_DIR}/app/build/outputs/apk
APK_FORMAT=*.apk

# UNSET JAVA_HOME SO GRADLE CAN PROPERLY SET IT
unset JAVA_HOME

# MOVE INTO SOURCE_DIR
cd "${SOURCE_DIR}"

# UPDATE REPO IF REQUESTED
echoText "UPDATING SOURCE"
git reset --hard HEAD

if [[ ${APK} != "substratum" ]]; then
    git pull
else
    if [[ $( git remote -v | grep upstream ) ]]; then
        git pull upstream dev && git push origin
    else
        reportWarning "Upstream remote not set; unable to update!"
    fi
fi

# MAKE NEW APK
echoText "BUILDING APK"
case ${ACTION} in
    "both"|"build"|"install")
        ./gradlew clean assembleRelease ;;
    *)
        reportError "Something serious has happened!" && exit
esac

APK_MOVE=${OUT_DIR}

# IF THE APK WAS FOUND, MOVE IT
if [[ $( ls "${OUT_DIR}"/${APK_FORMAT} 2>/dev/null | wc -l ) != "0" ]]; then
    RESULT_STRING="BUILD SUCCESSFUL"

    # SIGN APK
    APK_FILE=$( basename $( ls "${OUT_DIR}"/*.apk ) | sed s/.apk// )
    zipalign -v -p 4 "${OUT_DIR}"/${APK_FILE}.apk \
                     "${OUT_DIR}"/${APK_FILE}-aligned.apk
    if [[ ! -f "${OUT_DIR}"/${APK_FILE}-aligned.apk ]]; then
        reportError "There was an issue with zipalign!" && exit
    fi
    rm "${OUT_DIR}"/${APK_FILE}.apk
    apksigner sign --ks ${HOME}/Documents/Keys/key.jks \
                   --out "${OUT_DIR}"/${APK_NAME}.apk \
                   "${OUT_DIR}"/${APK_FILE}-aligned.apk
    if [[ ! -f "${OUT_DIR}"/${APK_NAME}.apk ]]; then
        reportError "There was an issue with signing the build!" && exit
    fi
    rm "${OUT_DIR}"/${APK_FILE}-aligned.apk

    if [[ ${ACTION} = "install" ]]; then
        adb install -r "${OUT_DIR}"/*.apk
    fi
else
    RESULT_STRING="BUILD FAILED"
fi

# END TIME TRACKING
END=$( TZ=MST date +%s )

# PRINT RESULT
# IF THE BUILD WAS SUCCESSFUL, PRINT FILE LOCATION AND SIZE
echoText "${RESULT_STRING}!"
if [[ ${RESULT_STRING} = "BUILD SUCCESSFUL" ]]; then
     echo -e ${RED}"FILE LOCATION: $( ls "${APK_MOVE}"/${APK_FORMAT} )"
     echo -e "SIZE: $( du -h "${APK_MOVE}"/${APK_FORMAT} | awk '{print $1}' )"${RST}
fi

 # PRINT HOW LONG IT TOOK REGARDLESS OF SUCCESS
 echo -e ${RED}"DURATION: $( format_time ${END} ${START} )"${RST}; newLine
