#!/bin/bash
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


################
#              #
#  ARCH CHECK  #
#              #
################

# CURRENTLY I BUILD ALL APKS ON MY PERSONAL MACHINE, NOT MY SERVER
if [[ -f /etc/arch-release ]]; then
    echo "Wrong window! ;)" && exit
fi


############
#          #
#  COLORS  #
#          #
############

BOLD="\033[1m"
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
    echo -e ""
    echo -e "${BOLD}OVERVIEW:${RESTORE} Builds and pushes the specified APK\n"
    echo -e "${BOLD}USAGE:${RESTORE} bash ${0} <apk> <options>\n"
    echo -e "${BOLD}EXAMPLE:${RESTORE} bash ${0} substratum build\n"
    echo -e "${BOLD}Required options:${RESTORE}"
    echo -e "   apk:       magisk | spectrum | substratum\n"
    echo -e "${BOLD}Other options (pick one):${RESTORE}"
    echo -e "   build:      update the source and builds the Substratum APK"
    echo -e "   install:    builds and pushes the APK to a local device"
    echo -e "   commit:     (Substratum and Magisk only) pull Flash-ROM/vendor_flash and commits then pushes the new APK"
    echo -e "   both:       does both build and commit\n"
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
        "build"|"both"|"install"|"push")
            ACTION=${1} ;;
        "-h"|"--help")
            help_menu ;;
        *)
            echo "Invalid parameter" && exit ;;
    esac

    shift
done

if [[ -z ${APK} ]]; then
    echo -e ${RED}"\nNo specified APK!"${RESTORE}
    help_menu
    exit
fi

if [[ -z ${ACTION} ]]; then
    echo -e ${RED}"\nYou did not specify the required action! Falling back to building only"${RESTORE}
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
        SOURCE_DIR=${HOME}/Documents/Repos/Substratum/official
        APK_NAME=Substratum ;;
    "spectrum")
        SOURCE_DIR=${HOME}/Documents/Repos/Spectrum ;;
esac
OUT_DIR=${SOURCE_DIR}/app/build/outputs/apk
APK_FORMAT=*.apk

# UNSET JAVA_HOME SO GRADLE CAN PROPERLY SET IT
unset JAVA_HOME

# GET CURRENT DIR FOR later
CURRENT_DIR=$( pwd )

# MOVE INTO SOURCE_DIR
cd "${SOURCE_DIR}"

# UPDATE REPO IF REQUESTED
if [[ "${ACTION}" == "build" ]] || [[ "${ACTION}" == "both" ]] || [[ "${ACTION}" == "install" ]]; then
    echoText "UPDATING SOURCE"
    git reset --hard HEAD && git pull

    # CLEAN PREVIOUS BUILD
    echoText "CLEANING BUILD"
    ./gradlew clean

    # MAKE NEW APK
    echoText "BUILDING APK"
    case ${ACTION} in
        "both"|"build")
            ./gradlew assembleDebug ;;
        "install")
            ./gradlew installDebug ;;
        *)
            echo -e ${RED}"Something serious has happened!"${RESTORE} && exit
    esac

    APK_MOVE=${OUT_DIR}

    # IF THE APK WAS FOUND, MOVE IT
    if [[ $( ls "${OUT_DIR}"/${APK_FORMAT} 2>/dev/null | wc -l ) != "0" ]]; then
        RESULT_STRING="BUILD SUCCESSFUL"
    else
        RESULT_STRING="BUILD FAILED"
    fi
fi

if [[ "${ACTION}" == "commit" ]] || [[ "${ACTION}" == "both" ]]; then
    COMMIT_HASH=$( git log -1 --format=%H )

    case ${APK} in
        "magisk")
            SOURCE_DIR=${HOME}/Documents/Repos/MagiskManager ;;
        "substratum")
            APK_MOVE=${HOME}/Documents/Repos/FlashVendor/prebuilt/app/Substratum
            VERSION=$( awk '/versionCode/{i++}i==2{print $2; exit}' "${SOURCE_DIR}"/app/build.gradle ) ;;
        *)
            echo -e ${RED}"\nCommitting is not supported by this APK\n"${RESTORE} && exit
    esac

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
        cp -v "${OUT_DIR}"/${APK_FORMAT} "${APK_MOVE}"/${APK_NAME}.apk

        # COMMIT IT
        echoText "PUSHING NEW APK"
        git add -A
        case ${APK} in
            "substratum")
                git commit --signoff -m "Substratum ${VERSION}: $( TZ=MST date +"%b %d %Y %r %Z" )

Compiled by @nathanchance
Device: MacBook Pro (13-inch, Mid 2012)
OS: macOS Sierra 10.12.3
Tools: NDK r14 and Android Studio 2.3

Currently here: https://github.com/substratum/substratum/commit/${COMMIT_HASH}
Full source: https://github.com/substratum/substratum

Please remember this is a debug APK so it is incompatible with
the Play Store release. Do not pick this if you have users on
your ROM." ;;
            "magisk")
                git commit --signoff -m "MagiskManager: Update to HEAD as of $( TZ=MST date +"%b %d %r %Z" )

Compiled by @nathanchance
Device: MacBook Pro (13-inch, Mid 2012)
OS: macOS Sierra 10.12.3
Tools: NDK r14 and Android Studio 2.3

Currently here: https://github.com/topjohnwu/MagiskManager/commit/${COMMIT_HASH}
Full source: https://github.com/topjohnwu/MagiskManager

The APK is a debug APK, it is incompatible with the Play Store
releases so do not add this if you have users of your ROM
(unless you want to build the APK every time there is a new
release)." ;;
        esac

        # PUSH IT
        git push
    else
        echo "Requested APK was not found; please run the script and use the build option!" && exit
    fi
fi

# END TIME TRACKING
END=$( TZ=MST date +%s )

# PRINT RESULT
# IF THE BUILD WAS SUCCESSFUL, PRINT FILE LOCATION AND SIZE
echoText "${RESULT_STRING}!"
if [[ ${RESULT_STRING} == "BUILD SUCCESSFUL" ]]; then
     echo -e ${RED}"FILE LOCATION: $( ls "${APK_MOVE}"/${APK_FORMAT} )"
     echo -e "SIZE: $( du -h "${APK_MOVE}"/${APK_FORMAT} | awk '{print $1}' )"${RESTORE}
fi

 # PRINT HOW LONG IT TOOK REGARDLESS OF SUCCESS
 echo -e ${RED}"DURATION: $( format_time ${END} ${START} )"${RESTORE}; newLine

# MOVE BACK TO ORIGINAL DIRECTORY
cd ${CURRENT_DIR}
