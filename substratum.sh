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
# USAGE: $ bash substratum.sh -h


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

# SOURCE OUR UNIVERSAL FUNCTIONS SCRIPT
source $( dirname ${BASH_SOURCE} )/funcs.sh

# PRINT A HELP MENU IF REQUESTED
function help_menu() {
    echo -e "\nOVERVIEW: Builds and pushes a Substratum APK\n"
    echo -e "USAGE: bash ${0} <options>\n"
    echo -e "EXAMPLE: bash ${0} build\n"
    echo -e "Possible options (pick one):"
    echo -e "   build:    update the source and builds the Substratum APK"
    echo -e "   push:     pull Flash-ROM/vendor_flash and pushes the new APK"
    echo -e "   both:     does both build and push\n"
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
        "build"|"push"|"both")
            PARAM=${1} ;;
        "-h"|"--help")
            help_menu ;;
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
if [[ -f /etc/arch-release ]]; then
    SOURCE_DIR=${HOME}/Repos/substratum
else
    SOURCE_DIR=${HOME}/Documents/Repos/Substratum/flash
fi
OUT_DIR=${SOURCE_DIR}/app/build/outputs/apk
APK_FORMAT=*ubstratum*.apk


# UNSET JAVA_HOME SO GRADLE CAN PROPERLY SET IT
unset JAVA_HOME

# GET CURRENT DIR FOR later
CURRENT_DIR=$( pwd )

# MOVE INTO SOURCE_DIR
cd "${SOURCE_DIR}"

# UPDATE REPO IF REQUESTED
if [[ "${PARAM}" == "build" || "${PARAM}" == "both" ]]; then
    echoText "UPDATING SOURCE"
    git pull && git pull upstream dev --rebase && git push --force

    # CLEAN PREVIOUS BUILD
    echoText "CLEANING BUILD"
    ./gradlew clean

    # MAKE NEW APK
    echoText "BUILDING APK"
    ./gradlew assembleDebug

    APK_MOVE=${OUT_DIR}

    # IF THE APK WAS FOUND, MOVE IT
    if [[ $( ls "${OUT_DIR}"/${APK_FORMAT} 2>/dev/null | wc -l ) != "0" ]]; then
        RESULT_STRING="BUILD SUCCESSFUL"
    else
        RESULT_STRING="BUILD FAILED"
    fi
fi

if [[ "${PARAM}" == "push" || "${PARAM}" == "both" ]]; then
    COMMIT_HASH=$( git log -1 --format=%H )
    VERSION=$( awk '/versionCode/{i++}i==2{print $2; exit}' "${SOURCE_DIR}"/app/build.gradle )

    if [[ -f /etc/arch-release ]]; then
        APK_MOVE=${HOME}/ROMs/Flash/vendor_flash/prebuilt/app/Substratum
        SECOND_MOVE=${HOME}/Web/Downloads/.superhidden/Substratum
    else
        APK_MOVE=${HOME}/Documents/Repos/FlashVendor/prebuilt/app/Substratum
    fi

    # IF THE APK WAS FOUND, MOVE IT
    if [[ $( ls "${OUT_DIR}"/${APK_FORMAT} 2>/dev/null | wc -l ) != "0" ]]; then
        # CLEAN/MAKE APK_MOVE
        if [[ -d "${APK_MOVE}" ]]; then
            rm -vrf "${APK_MOVE}"/${APK_FORMAT}
        else
            mkdir -p "${APK_MOVE}"
        fi

        # UPDATE APK_MOVE
        echoText "MOVING APK"
        cd "${APK_MOVE}" && git pull

        # MOVE NEW APK
        cp -v "${OUT_DIR}"/${APK_FORMAT} "${APK_MOVE}"/Substratum.apk
        if [[ -f /etc/arch-release ]]; then
            cp -v "${OUT_DIR}"/"${APK_FORMAT}" "${SECOND_MOVE}"
        fi

        # COMMIT IT
        echoText "PUSHING NEW APK"
        git add -A
        git commit --signoff -m "Substratum ${VERSION}: $( TZ=MST date +"%b %d %Y %r %Z" )

Compiled by @nathanchance
Device: MacBook Pro (13-inch, Mid 2012)
OS: macOS Sierra 10.12.3
Tools: NDK r14 and Android Studio 2.3

Currently here: https://github.com/Flash-ROM/substratum/commit/${COMMIT_HASH}
Full source: https://github.com/Flash-ROM/substratum

Please remember this is a debug APK so it is incompatible with the Play Store release. Do not pick this if you have users on your ROM."

        # PUSH IT
        git push
    else
        echo "Substratum APK was not found; please run the script and use the build option!" && exit
    fi
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
 echo -e ${RED}"DURATION: $( format_time ${END} ${START} )"${RESTORE}; newLine

# MOVE BACK TO ORIGINAL DIRECTORY
cd ${CURRENT_DIR}
