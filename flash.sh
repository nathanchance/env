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
    echo -e "    -v | --verbose:     Compile verbosely (show full errors/warnings)\n"
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
                "4.9"|"7.x")
                    TOOLCHAIN_NAME=${1} ;;
                *)
                    reportError "Invalid toolchain!" ;;
            esac ;;

        "-v"|"--verbose")
            VERBOSE=true ;;

        *)
            reportError "Invalid parameter" ;;
    esac

    shift
done

# DEFAULT PARAMETERS
[[ -z ${BRANCH} ]] && BRANCH="7.1.2-flash-staging"
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
SOURCE_FOLDER=${KERNEL_HEAD}/${DEVICE}
OUT_FOLDER=${SOURCE_FOLDER}/out
ANYKERNEL_FOLDER=${KERNEL_HEAD}/anykernel
ZIP_MOVE_HEAD=${HOME}/Web/Downloads

case ${TOOLCHAIN_NAME} in
    "4.9")
        TOOLCHAIN_FOLDER=aosp-4.9
        TOOLCHAIN_PREFIX=aarch64-linux-android- ;;
    "7.x")
        TOOLCHAIN_FOLDER=linaro-7.x
        TOOLCHAIN_PREFIX=aarch64-linaro-linux-gnu- ;;
esac

TOOLCHAIN_FOLDER=${HOME}/Toolchains/${TOOLCHAIN_FOLDER}

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
KERNEL=${OUT_FOLDER}/arch/${ARCHITECTURE}/boot/${KERNEL_IMAGE}



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
    git clean -fxd

    # CLEAN SOURCE FOLDER
    cd "${SOURCE_FOLDER}"
    # ONLY CHECKOUT IF WE AREN'T BISECTING OR REBASING
    [[ ! $( git status | ag "bisec|rebas" ) ]] && git checkout ${KERNEL_BRANCH}
    git clean -fxd
}


# MAKE KERNEL
function makeKernel() {
    cd "${SOURCE_FOLDER}"

    # SET MAKE VARIABLE FOR CONVENIENCE
    # AS I FOOLISHLY LEARNED, ALL CAF CODE REQUIRES AN OUTPUT DIRECTORY
    # TO WORK PROPERLY SO WHILE MY NEXUS DOESN'T CURRENTLY REQUIRE IT,
    # IT'S GOOD TO BE AHEAD OF THE CURVE IF IT WORKS.
    MAKE="make O=${OUT_FOLDER}"

    # PROPERLY POINT COMPILER TO TOOLCHAIN AND ARCHITECTURE
    export CROSS_COMPILE=${TOOLCHAIN_FOLDER}/bin/${TOOLCHAIN_PREFIX}
    export ARCH=${ARCHITECTURE}
    export SUBARCH=${ARCHITECTURE}

    # SETUP OUT FOLDER OR CLEAN IT
    if [[ -d ${OUT_FOLDER} ]]; then
        ${MAKE} clean
        ${MAKE} mrproper
    else
        mkdir -p ${OUT_FOLDER}
    fi

    # POINT TO PROPER DEFCONFIG
    ${MAKE} ${DEFCONFIG}

    # MAKE THE KERNEL
    time ${MAKE} ${THREADS}
}


# PRINT ZIP INFO
function printKernelInfo() {
    # KERNEL VERSION IS AUTOMATICALLY GENERATED
    export KERNEL_VERSION=$( cat ${OUT_FOLDER}/include/config/kernel.release )
    export ZIP_NAME=$( echo ${KERNEL_VERSION} | sed "s/^[^-]*-//g" )
    export KERNEL_ZIP=${ZIP_NAME}.zip

    echo -e "${BOLD}Kernel version:${RST} ${KERNEL_VERSION}"
    echo -e "${BOLD}Kernel zip:${RST} ${KERNEL_ZIP}"; newLine
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

    # IF IT ISN'T A PUBLIC BUILD, CLEAN THE FOLDER
    if [[ ${MODE} != "public" ]]; then
        rm -rf "${ZIP_MOVE}"/*
    else
        # OTHERWISE, MOVE THE OLD FILES TO AN "OLD" FOLDER
        [[ ! -d "${ZIP_MOVE}"/Old ]] && mkdir -p "${ZIP_MOVE}"/Old
        mv $( find "${ZIP_MOVE}"/* -maxdepth 0 -type f ) "${ZIP_MOVE}"/Old
    fi
}


# PACKAGE ZIP
function packageZip() {
    cd "${ANYKERNEL_FOLDER}"

    # MOVE THE KERNEL IMAGE
    cp "${KERNEL}" "${ANYKERNEL_FOLDER}"

    # PACKAGE THE ZIP WITHOUT THE README
    zip -q -r9 ${KERNEL_ZIP} * -x README.md ${KERNEL_ZIP}
}


# MOVE FILES
function moveFiles() {
    # IF PACKAGING FAILED, ERROR OUT
    [[ ! -f ${KERNEL_ZIP} ]] && reportError "Kernel zip not found!"

    # MOVE THE KERNEL ZIP TO WHERE IT NEEDS TO GO
    mv ${KERNEL_ZIP} "${ZIP_MOVE}"

    # IF IT IS A TEST BUILD, UPLOAD IT
    if [[ ${MODE} = "test" ]]; then
        URL=$( curl -s --upload-file "${ZIP_MOVE}/${KERNEL_ZIP}" \
               "https://transfer.sh/${KERNEL_ZIP}" )
    fi

    # GENERATE MD5SUM
    md5sum "${ZIP_MOVE}"/${KERNEL_ZIP} > "${ZIP_MOVE}"/${KERNEL_ZIP}.md5sum
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
    # ONLY PRINT FILE INFO IF IT EXISTS
    if [[ ${SUCCESS} = true ]]; then
        case ${MODE} in
            "private"|"public")
                echo -e ${RED}"FILE LOCATION: ${ZIP_MOVE}/${KERNEL_ZIP}"
                echo -e "SIZE: $( du -h ${ZIP_MOVE}/${KERNEL_ZIP} |
                                  awk '{print $1}' )"${RST} ;;
            "test")
                echo -e ${RED}"FILE LOCATION: ${URL}"${RST} ;;
        esac
    fi

    # PRINT TIME INFO REGARDLESS OF SUCCESS
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
                echo -e "FILE LOCATION: ${ZIP_MOVE}/${KERNEL_ZIP}" >> ${LOG} ;;
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

# SET THE START OF THE SCRIPT AND CLEAR TERMINAL
START=$( date +"%s" ) && clear


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


#################
# MAKING KERNEL #
#################

echoText "CLEANING UP AND MAKING KERNEL"

# DON'T SHOW CLEAN UP OUTPUT
cleanUp &>/dev/null

# ONLY SHOW ERRORS, WARNINGS, AND THE IMAGE LINE WHEN COMPILING (UNLESS VERBOSE)
if [[ ${VERBOSE} = true ]]; then
    makeKernel
else
    makeKernel |& ag --no-color "error:|warning:|${KERNEL_IMAGE}"
fi


######################
# IF KERNEL COMPILED #
######################

if [[ $( ls ${KERNEL} | wc -l ) != 0 ]]; then
    # SET BUILD SUCCESS STRING AND SUCCESS VARIABLE
    BUILD_RESULT="BUILD SUCCESSFUL" && SUCCESS=true

    newLine; echoText "MAKING AND MOVING FLASHABLE ZIP"

    # PRINT KERNEL AND ZIP INFO
    printKernelInfo

    # TAG THE HEAD COMMIT FOR PUBLIC BUILD
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


######################
# ENDING INFORMATION #
######################

END=$( date +"%s" )

echoText "${BUILD_RESULT}!"

endingInfo

generateLog

# KILL TMP FOLDER
[[ ${MODE} = "test" ]] && rm -rf ${ZIP_MOVE}

echo -e "\a"
