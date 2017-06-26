#!/usr/bin/env bash
#
# Flash Kernel compilation script
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

# PURPOSE: Build Flash Kernel and package it into a flashable zip
# USAGE: $ bash kernel.sh -h


###################
#                 #
#  INITIAL SETUP  #
#                 #
###################

# SOURCE OUR UNIVERSAL FUNCTIONS SCRIPT AND MAC CHECK
SCRIPT_DIR=$( cd $( dirname $( readlink -f "${BASH_SOURCE[0]}" ) ) && pwd )
source ${SCRIPT_DIR}/funcs.sh && macCheck

# PRINT A HELP MENU IF REQUESTED
function help_menu() {
    echo -e ""
    echo -e "${BOLD}OVERVIEW:${RST} Builds and packages Flash Kernel\n"
    echo -e "${BOLD}USAGE:${RST} bash ${0} <options>\n"
    echo -e "${BOLD}EXAMPLE:${RST} bash ${0} -m public -t 4.9 -c angler_defconfig\n"
    echo -e "${BOLD}OPTIONAL PARAMETERS:${RST}"
    echo -e "    -b | --branch:      The branch to compile"
    echo -e "    -c | --config:      The defconfig to use while compiling"
    echo -e "    -d | --device:      The device to compile"
    echo -e "    -m | --mode:        A public, private, or test kernel"
    echo -e "    -t | --toolchain:   Compile with 4.9 or 7.x"
    echo -e ""
    echo -e "No options will build an Angler kernel and push to private folder\n"
    exit
}


################
#              #
#  PARAMETERS  #
#              #
################

# GATHER PARAMETERS
while [[ $# -ge 1 ]]; do
    case "${1}" in
        "-b"|"--branch")
            shift

            if [[ $# -ge 1 ]]; then
                BRANCH=${1}
            else
                reportError "Please specify a branch!"
            fi ;;

        "-c"|"--config")
            shift

            if [[ $# -ge 1 ]]; then
                DEFCONFIG=${1}
            else
                reportError "Please specify a defconfig!"
            fi ;;

        "-d"|"--device")
            shift

            case ${1} in
                "angler")
                    DEVICE=${1} ;;
                *)
                    reportError "Invalid device!" ;;
            esac ;;

        "-h"|"--help")
            help_menu ;;

        "-m"|"--mode")
            shift

            case ${1} in
                "private"|"public"|"test")
                    MODE=${1} ;;
                *)
                    reportError "Invalid mode!" ;;
            esac ;;

        "-t"|"--toolchain")
            shift

            case "${1}" in
                "4.9")
                    TOOLCHAIN_NAME=${1} ;;
                *)
                    reportError "Invalid toolchain!" ;;
            esac ;;

        *)
            reportError "Invalid parameter" ;;
    esac

    shift
done

# DEFAULT PARAMETERS
[[ -z ${BRANCH} ]] && BRANCH="7.1.2-flash"
[[ -z ${DEFCONFIG} ]] && DEFCONFIG="flash_defconfig"
[[ -z ${DEVICE} ]] && DEVICE="angler"
[[ -z ${MODE} ]] && MODE="private"
[[ -z ${TOOLCHAIN_NAME} ]] && TOOLCHAIN_NAME="7.x"


###############
#             #
#  VARIABLES  #
#             #
###############

# FOLDERS
KERNEL_HEAD=${HOME}/Kernels
ZIP_MOVE_HEAD=${HOME}/Web/Downloads
TOOLCHAIN_HEAD=${HOME}/Toolchains
ANYKERNEL_FOLDER=${KERNEL_HEAD}/ak
SOURCE_FOLDER=${KERNEL_HEAD}/${DEVICE}

case ${TOOLCHAIN_NAME} in
    "4.9")
        TOOLCHAIN_FOLDER=AOSP-4.9
        TOOLCHAIN_PREFIX=aarch64-linux-android- ;;
    "7.x")
        TOOLCHAIN_FOLDER=aarch64-linaro-linux-gnu-7.x
        TOOLCHAIN_PREFIX=aarch64-linaro-linux-gnu- ;;
esac

TOOLCHAIN_FOLDER=${TOOLCHAIN_HEAD}/${TOOLCHAIN_FOLDER}

case ${MODE} in
    "private")
        ZIP_MOVE=${ZIP_MOVE_HEAD}/../me/Flash-Kernel
        ANYKERNEL_BRANCH=${DEVICE}-flash-personal-7.1.2 ;;
    "public")
        ZIP_MOVE=${ZIP_MOVE_HEAD}/Kernels
        ANYKERNEL_BRANCH=${DEVICE}-flash-public-7.1.2 ;;
    "test")
        ZIP_MOVE=${ZIP_MOVE_HEAD}/.tmp
        ANYKERNEL_BRANCH=${DEVICE}-flash-public-7.1.2 ;;
esac

# KERNEL INFO
ARCHITECTURE=arm64
KERNEL_IMAGE=Image.gz-dtb
THREADS=-j$( nproc --all )
KERNEL=${SOURCE_FOLDER}/arch/${ARCHITECTURE}/boot/${KERNEL_IMAGE}


###############
#             #
#  FUNCTIONS  #
#             #
###############

# CLEAN UP
function cleanUp() {
    # CLEAN ANYKERNEL FOLDER
    cd "${ANYKERNEL_FOLDER}"
    git checkout ${ANYKERNEL_BRANCH}
    git clean -fxd > /dev/null 2>&1
}

# MAKE KERNEL
function makeKernel() {
    cd "${SOURCE_FOLDER}"

    # PROPERLY POINT COMPILER TO TOOLCHAIN AND ARCHITECTURE
    export CROSS_COMPILE=${TOOLCHAIN_FOLDER}/bin/${TOOLCHAIN_PREFIX}
    export ARCH=${ARCHITECTURE}
    export SUBARCH=${ARCHITECTURE}

    # CLEAN PREVIOUSLY COMPILED FILES AND DEFCONFIG
    make clean && make mrproper

    # POINT TO PROPER DEFCONFIG
    make ${DEFCONFIG}

    # MAKE THE KERNEL
    time make ${THREADS} | tee -a ${LOGDIR}/Compilation/Kernels/${ZIP_NAME}.log
}

# GETS A FORMATTED ZIP_NAME
function getZipName() {
    echo $( cat ${SOURCE_FOLDER}/include/config/kernel.release |
            sed "s/^.*flash-/flash-/g" )-$( date +%H%M )
}

# TAG FOR RELEASES
function tagRelease() {
    # WE NEED TO MARK THE PREVIOUS TAG FOR CHANGELOG
    PREV_TAG_NAME=$(git tag -l --sort=-taggerdate | grep -m 1 flash)
    PREV_TAG_HASH=$(git log --format=%H -1 ${PREV_TAG_NAME})

    git tag -a "${ZIP_NAME}" -m "${ZIP_NAME}"
    git push origin "${ZIP_NAME}"
}

# SETUP FOLDERS
function setupFolders() {
    # IF ZIPMOVE DOESN'T EXIST, MAKE IT
    [[ ! -d "${ZIP_MOVE}" ]] && mkdir -p "${ZIP_MOVE}"

    # IF IT ISN'T A PUBLIC BUILD, CLEAN THE FOLDER; OTHERWISE, MOVE THE OLD FILES
    if [[ ${MODE} != "public" ]]; then
        rm -rf "${ZIP_MOVE}"/*
    else
        [[ ! -d "${ZIP_MOVE}"/Old ]] && mkdir -p "${ZIP_MOVE}"/Old
        mv $( find "${ZIP_MOVE}"/* -maxdepth 0 -type f ) "${ZIP_MOVE}"/Old
    fi
}

# PACKAGE ZIP
function packageZip() {
    cd "${ANYKERNEL_FOLDER}"

    cp "${KERNEL}" "${ANYKERNEL_FOLDER}"

    zip -r9 ${ZIP_NAME}.zip * -x README.md ${ZIP_NAME}.zip > /dev/null 2>&1
}

# MOVE FILES
function moveFiles() {
    [[ ! -f ${ZIP_NAME}.zip ]] && reportError "Kernel zip not found!"

    mv ${ZIP_NAME}.zip "${ZIP_MOVE}"

    # IF IT IS A TEST BUILD, UPLOAD IT
    if [[ ${MODE} = "test" ]]; then
        URL=$( curl -s --upload-file "${ZIP_MOVE}/${ZIP_NAME}.zip" \
               "https://transfer.sh/${ZIP_NAME}.zip" )
    fi

    md5sum "${ZIP_MOVE}"/${ZIP_NAME}.zip > "${ZIP_MOVE}"/${ZIP_NAME}.zip.md5sum
}

# GENERATE CHANGELOG
function generateChangelog() {
    git -C "${SOURCE_FOLDER}" log --format="%nTitle: %s
Author: %aN <%aE>
Authored on: %aD\
Link: http://github.com/nathanchance/angler/commit/%H
Added on: %cD%n" ${PREV_TAG_HASH}..HEAD > "${ZIP_MOVE}"/${ZIP_NAME}-changelog.txt
}

# PRINT FILE INFO
function endingInfo() {
    if [[ ${SUCCESS} = true ]]; then
        case ${MODE} in
            "private"|"public")
                echo -e ${RED}"FILE LOCATION: ${ZIP_MOVE}/${ZIP_NAME}.zip"
                echo -e "SIZE: $( du -h ${ZIP_MOVE}/${ZIP_NAME}.zip |
                                  awk '{print $1}' )"${RST} ;;
            "test")
                echo -e ${RED}"FILE LOCATION: ${URL}"${RST} ;;
        esac
    fi

    echo -e ${RED}"TIME: $( date +%D\ %r | awk '{print toupper($0)}' )"
    echo -e "DURATION: $( format_time ${END} ${START} )"${RST}; newLine
}

# LOG GENERATION
function generateLog() {
    # DATE: BASH_SOURCE (PARAMETERS)
    # BUILD <SUCCESSFUL|FAILED> IN # MINUTES AND # SECONDS
    echo -e "\n$( date +"%m/%d/%Y %H:%M:%S" ): ${BASH_SOURCE} ${1}" >> ${LOG}
    echo -e "${BUILD_RESULT} IN $( format_time ${END} ${START} )" >> ${LOG}

    # ONLY ADD A LINE ABOUT FILE LOCATION IF SCRIPT COMPLETED SUCCESSFULLY
    if [[ ${SUCCESS} = true ]]; then
        # FILE LOCATION: PATH
        case ${MODE} in
            "private"|"public")
                echo -e "FILE LOCATION: ${ZIP_MOVE}/${ZIP_NAME}.zip" >> ${LOG} ;;
            "test")
                echo -e "FILE LOCATION: ${URL}" >> ${LOG} ;;
        esac
    fi
}


################
#              #
# SCRIPT START #
#              #
################

# SET THE START OF THE SCRIPT
START=$( date +"%s" )

# SILENTLY SHIFT KERNEL BRANCHES
clear && cd "${SOURCE_FOLDER}"

# ONLY CHECKOUT IF WE ARE NOT CURRENTLY BISECTING OR REBASING
if [[ ! $(git status | grep "bisect\|rebase") ]]; then
    git checkout ${KERNEL_BRANCH} > /dev/null 2>&1
fi


###################
# SHOW ASCII TEXT #
###################

echo -e ${RED}; newLine
echo -e "================================================================================================"; newLine; newLine
echo -e "  ___________________________________  __   ______ _______________________   ________________   "
echo -e "  ___  ____/__  /___    |_  ___/__  / / /   ___  //_/__  ____/__  __ \__  | / /__  ____/__  /   "
echo -e "  __  /_   __  / __  /| |____ \__  /_/ /    __  ,<  __  __/  __  /_/ /_   |/ /__  __/  __  /    "
echo -e "  _  __/   _  /___  ___ |___/ /_  __  /     _  /| | _  /___  _  _, _/_  /|  / _  /___  _  /___  "
echo -e "  /_/      /_____/_/  |_/____/ /_/ /_/      /_/ |_| /_____/  /_/ |_| /_/ |_/  /_____/  /_____/  "; newLine; newLine; newLine
echo -e "================================================================================================"; newLine


####################
# CLEANING FOLDERS #
####################

echoText "CLEANING UP"

cleanUp


#################
# MAKING KERNEL #
#################

echoText "MAKING KERNEL"

makeKernel


######################
# IF KERNEL COMPILED #
######################

if [[ $( ls ${KERNEL} 2>/dev/null | wc -l ) != 0 ]]; then
    # SET BUILD SUCCESS STRING AND SUCCESS VARIABLE
    BUILD_RESULT="BUILD SUCCESSFUL"
    SUCCESS=true

    # PRINT PACKAGING
    newLine; echoText "MAKING AND MOVING FLASHABLE ZIP"

    # GENERATE ZIP_NAME
    ZIP_NAME=$( getZipName )

    # TAG THE HEAD COMMIT WITH THE VERSION FIRST IF IT'S A PUBLIC BUILD
    [[ ${MODE} = "public" ]] && tagRelease

    # SETUP ENVIRONMENT AND MAKE/MOVE ZIP
    setupFolders
    packageZip
    moveFiles

    # GENERATE CHANGELOG FOR PUBLIC BUILD
    [[ ${MODE} = "public" ]] && generateChangelog

###################
# IF BUILD FAILED #
###################

else
    BUILD_RESULT="BUILD FAILED"
    SUCCESS=false
fi


##############
# SCRIPT END #
##############

echoText "${BUILD_RESULT}!"

END=$( date +"%s" )


######################
# ENDING INFORMATION #
######################

endingInfo


##################
# LOG GENERATION #
##################

generateLog


##############
# SCRIPT END #
##############

# KILL TMP FOLDER
[[ ${MODE} = "test" ]] && rm -rf ${ZIP_MOVE}

echo -e "\a"
