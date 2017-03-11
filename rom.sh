#!/bin/bash
#
# ROM compilation script
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

# PURPOSE: Build an Android ROM from source
# USAGE:
# $ rom.sh me
# $ rom.sh <flash|pn|du|abc|krexus|aosip|vanilla> <shamu|angler|bullhead|hammerhead>


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

# SOURCE OUR UNIVERSAL FUNCTIONS SCRIPT
source $( dirname ${BASH_SOURCE} )/funcs.sh

# UNSETS VARIABLES POTENTIALLY USED IN SCRIPT
function unsetvars() {
    unset ROM_BUILD_TYPE HAS_SUBSTRATUM LOCALVERSION BUILD_TAG HAS_ROUNDICONS
    unset SYNC PERSONAL SUCCESS CLEAN_TYPE MAKE_TYPE PARAMS HAS_ROOT HAS_GAPPS
    unset PIXEL PUBLIC
}

# CHECKS IF MKA EXISTS
function make_command() {
    while [[ $# -ge 1 ]]; do
        MAKE_PARAMS+="${1} "

        shift
    done

    if [[ -n $( command -v mka ) ]]; then
        mka ${MAKE_PARAMS}
    else
        make -j$( grep -c ^processor /proc/cpuinfo ) ${PARAMS}
    fi

    unset MAKE_PARAMS
}


################
#              #
#  PARAMETERS  #
#              #
################

unsetvars

while [[ $# -ge 1 ]]; do
    PARAMS+="${1} "

    case "${1}" in
        "shamu"|"angler"|"bullhead"|"hammerhead"|"marlin"|"sailfish")
            DEVICE=${1} ;;
        "abc"|"aosip"|"du"|"flash"|"krexus"|"pn"|"vanilla")
            ROM=${1} ;;
        "sync")
            SYNC=true ;;
        "type")
            shift
            if [[ $# -ge 1 ]]; then
                PARAMS+="${1} "
                export BUILD_TAG=${1}
            else
                echo "Please specify a build type!" && exit
            fi ;;
        "clean")
            shift
            if [[ $# -ge 1 ]]; then
                PARAMS+="${1} "
                export CLEAN_TYPE=${1}
            else
                echo "Please specify a clean type!" && exit
            fi ;;
        "make")
            shift
            if [[ $# -ge 1 ]]; then
                PARAMS+="${1} "
                export MAKE_TYPE=${1}
            else
                echo "Please specify a make item!" && exit
            fi ;;
        "nosubs")
            export HAS_SUBSTRATUM=false ;;
        "noroot")
            export HAS_ROOT=false ;;
        "noicons")
            export HAS_ROUNDICONS=false ;;
        "nogapps")
            export HAS_GAPPS=false ;;
        "pixel")
            export PIXEL=true ;;
        "public")
            export PUBLIC=true ;;
        "me")
            ROM=flash
            shift
            if [[ $# -ge 1 ]]; then
                PARAMS+="${1} "
                DEVICE=${1}
            else
                DEVICE=angler
            fi
            export LOCALVERSION=-$( TZ=MST date +%Y%m%d ) ;;
        "plain")
            ROM=flash
            shift
            if [[ $# -ge 1 ]]; then
                PARAMS+="${1} "
                DEVICE=${1}
            else
                DEVICE=angler
            fi
            export LOCALVERSION=-$( TZ=MST date +%Y%m%d )
            export HAS_SUBSTRATUM=false
            export HAS_ROOT=false
            export HAS_ROUNDICONS=false
            export HAS_GAPPS=false ;;
        *)
            echo "Invalid parameter detected!" && exit ;;
    esac

    shift
done

# PARAMETER VERIFICATION
if [[ -z ${DEVICE} || -z ${ROM} ]]; then
    echo "You did not specify a necessary parameter!" && exit
fi

###############
#             #
#  VARIABLES  #
#             #
###############

# ANDROID_DIR: Directory that holds all of the Android files
# OUT_DIR: Directory that holds the compiled ROM files
# SOURCE_DIR: Directory that holds the ROM source
# ZIP_MOVE: Directory to hold completed ROM zips
ANDROID_DIR=${HOME}
ZIP_MOVE_PARENT=${HOME}/Web/Downloads/.superhidden/ROMs

# Otherwise, define them for our various ROMs
case "${ROM}" in
    "abc")
        SOURCE_DIR=${ANDROID_DIR}/ROMs/ABC
        ZIP_MOVE=${ZIP_MOVE_PARENT}/ABC/${DEVICE} ;;
    "aosip")
        SOURCE_DIR=${ANDROID_DIR}/ROMs/AOSiP
        ZIP_MOVE=${ZIP_MOVE_PARENT}/AOSiP/${DEVICE} ;;
    "du")
        SOURCE_DIR=${ANDROID_DIR}/ROMs/DU
        ZIP_MOVE=${ZIP_MOVE_PARENT}/DirtyUnicorns/${DEVICE} ;;
    "flash")
        SOURCE_DIR=${ANDROID_DIR}/ROMs/Flash
        ZIP_MOVE=${ZIP_MOVE_PARENT}/Flash/${DEVICE} ;;
    "krexus")
        SOURCE_DIR=${ANDROID_DIR}/ROMs/Krexus
        ZIP_MOVE=${ZIP_MOVE_PARENT}/Krexus/${DEVICE} ;;
    "pn")
        SOURCE_DIR=${ANDROID_DIR}/ROMs/PN
        ZIP_MOVE=${ZIP_MOVE_PARENT}/PureNexus/${DEVICE} ;;
    "vanilla")
        SOURCE_DIR=${ANDROID_DIR}/ROMs/Vanilla
        ZIP_MOVE=${ZIP_MOVE_PARENT}/Vanilla/${DEVICE} ;;
esac

OUT_DIR=${SOURCE_DIR}/out/target/product/${DEVICE}


###########################
# MOVE INTO SOURCE FOLDER #
# AND START TRACKING TIME #
###########################

START=$( TZ=MST date +%s )
clear && cd ${SOURCE_DIR}


#############
# REPO SYNC #
#############

# IF THE SYNC IS REQUESTED, DO SO
if [[ ${SYNC} = true ]]; then
    echoText "SYNCING LATEST SOURCES"; newLine

    repo sync --force-sync -j$( grep -c ^processor /proc/cpuinfo )

# IF IT'S MY OWN ROM, ALWAYS SYNC KERNEL, GAPPS, AND VENDOR REPOS BECAUSE THOSE
# ARE EXTERNALLY UPDATED. EVERYTHING ELSE WILL BE EITHER LOCALLY TRACKED OR
# SYNCED WHEN IT MATTERS
elif [[ "${ROM}" == "flash" ]]; then
    echoText "SYNCING REQUESTED REPOS"; newLine

    REPOS="kernel/huawei/angler vendor/google/build vendor/opengapps/sources/all
    vendor/opengapps/sources/arm vendor/opengapps/sources/arm64 vendor/flash"
    repo sync --force-sync -j$( grep -c ^processor /proc/cpuinfo ) ${REPOS}
fi


###########################
# SETUP BUILD ENVIRONMENT #
###########################

echoText "SETTING UP BUILD ENVIRONMENT"

# CHECK AND SEE IF WE ARE ON ARCH
# IF SO, ACTIVARE A VIRTUAL ENVIRONMENT FOR PROPER PYTHON SUPPORT
if [[ -f /etc/arch-release ]]; then
    virtualenv2 ${HOME}/venv && source ${HOME}/venv/bin/activate
fi

source build/envsetup.sh


##################
# PREPARE DEVICE #
##################

echoText "PREPARING $( echo ${DEVICE} | awk '{print toupper($0)}' )"

# NOT ALL ROMS USE BREAKFAST
case "${ROM}" in
    "aosip")
        lunch aosip_${DEVICE}-userdebug ;;
    "krexus")
        lunch krexus_${DEVICE}-user ;;
    "vanilla")
        lunch vanilla_${DEVICE}-userdebug ;;
    *)
        breakfast ${DEVICE} ;;
esac


############
# CLEAN UP #
############

echoText "CLEANING UP OUT DIRECTORY"

if [[ -n ${CLEAN_TYPE} ]] && [[ "${CLEAN_TYPE}" != "noclean" ]]; then
    make_command ${CLEAN_TYPE}
elif [[ -z ${CLEAN_TYPE} ]]; then
    make_command clobber
fi


##################
# START BUILDING #
##################

echoText "MAKING FILES"; newLine

NOW=$( TZ=MST date +"%Y-%m-%d-%S" )

# MAKE THE REQUESTED ITEM
if [[ -n ${MAKE_TYPE} ]]; then
    time make_command ${MAKE_TYPE}

    ################
    # PRINT RESULT #
    ################

    newLine; echoText "BUILD COMPLETED!"
else
    # NOT ALL ROMS USE BACON
    case "${ROM}" in
        "aosip")
            time make_command kronic ;;
        "flash")
            time make_command flash ;;
        "krexus")
            time make_command otapackage ;;
        "vanilla")
            time make_command vanilla ;;
        *)
            time make_command bacon ;;
    esac

    ###################
    # IF ROM COMPILED #
    ###################

    # THERE WILL BE A ZIP IN THE OUT FOLDER IF SUCCESSFUL
    FILES=$( ls ${OUT_DIR}/*.zip 2>/dev/null | wc -l )
    if [[ ${FILES} != "0" ]]; then
        # MAKE BUILD RESULT STRING REFLECT SUCCESSFUL COMPILATION
        BUILD_RESULT_STRING="BUILD SUCCESSFUL"
        SUCCESS=true


        ##################
        # ZIP_MOVE LOGIC #
        ##################

        # MAKE ZIP_MOVE IF IT DOESN'T EXIST OR CLEAN IT IF IT DOES
        if [[ ! -d "${ZIP_MOVE}" ]]; then
            mkdir -p "${ZIP_MOVE}"
        else
            rm -rf "${ZIP_MOVE}"/*
        fi


        ####################
        # MOVING ROM FILES #
        ####################

        newLine; echoText "MOVING FILES TO ZIP_MOVE DIRECTORY"
        if [[ ${FILES} = 1 ]]; then
            mv -v "${OUT_DIR}"/*.zip* "${ZIP_MOVE}"
        else
            for FILE in $( ls ${OUT_DIR}/*.zip* | grep -v ota ); do
                mv -v "${FILE}" "${ZIP_MOVE}"
            done
        fi


    ###################
    # IF BUILD FAILED #
    ###################

    else
        BUILD_RESULT_STRING="BUILD FAILED"
        SUCCESS=false
    fi

    ################
    # PRINT RESULT #
    ################

    echoText "${BUILD_RESULT_STRING}!"
fi


# DEACTIVATE VIRTUALENV IF WE ARE ON ARCH
if [[ -f /etc/arch-release ]]; then
    deactivate && rm -rf ${HOME}/venv
fi


######################
# ENDING INFORMATION #
######################

# STOP TRACKING TIME
END=$( TZ=MST date +%s )

# IF THE BUILD WAS SUCCESSFUL, PRINT FILE LOCATION, AND SIZE
if [[ ${SUCCESS} = true ]]; then
    echo -e ${RED}"FILE LOCATION: $( ls ${ZIP_MOVE}/*.zip )"
    echo -e "SIZE: $( du -h ${ZIP_MOVE}/*.zip | awk '{print $1}' )"${RESTORE}
fi

# PRINT THE TIME THE SCRIPT FINISHED
# AND HOW LONG IT TOOK REGARDLESS OF SUCCESS
echo -e ${RED}"TIME: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
echo -e ${RED}"DURATION: $( format_time ${END} ${START} )"${RESTORE}; newLine


##################
# LOG GENERATION #
##################

# DATE: BASH_SOURCE (PARAMETERS)
echo -e "\n$( TZ=MST date +%H:%M:%S ): ${BASH_SOURCE} ${PARAMS}" >> ${LOG}

# BUILD <SUCCESSFUL|FAILED> IN # MINUTES AND # SECONDS
if [[ -n ${BUILD_RESULT_STRING} ]]; then
    echo -e "${BUILD_RESULT_STRING} IN \c" >> ${LOG}
fi
echo -e "$( format_time ${END} ${START} )" >> ${LOG}

# ONLY ADD A LINE ABOUT FILE LOCATION IF SCRIPT COMPLETED SUCCESSFULLY
if [[ ${SUCCESS} = true ]]; then
    # FILE LOCATION: <PATH>
    echo -e "FILE LOCATION: $( ls ${ZIP_MOVE}/*.zip )" >> ${LOG}
fi


########################
# ALERT FOR SCRIPT END #
########################

echo -e "\a" && cd ${HOME}

# UNSET EXPORTS
unsetvars
