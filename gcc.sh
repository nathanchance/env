#!/usr/bin/env bash
#
# gcc toolchains compilation script
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

# PURPOSE: Builds aarch64-linux-android and arm-linux-androideabi toolchains from source
# USAGE: $ bash gcc.sh -h

# PRINT A HELP MENU IF REQUESTED
if [[ -n ${1} ]]; then
    echo -e ""
    echo -e "${BOLD}OVERVIEW:${RST} Build a set of GCC 6 toolchains and uploads them to Flash-ROM's Gitlab\n"
    echo -e "${BOLD}USAGE:${RST} bash ${0}\n"
    exit
fi


###############
#             #
#  VARIABLES  #
#             #
###############

TOOLCHAIN_HEAD=${HOME}/Toolchains
SCRIPTS_DIR=${TOOLCHAIN_HEAD}/Flash-TC/scripts


###############
#             #
#  FUNCTIONS  #
#             #
###############

# SOURCE OUR UNIVERSAL FUNCTIONS SCRIPT
source $( dirname ${BASH_SOURCE} )/funcs.sh

# MAC CHECK; THIS SCRIPT SHOULD ONLY BE RUN ON LINUX
if [[ $( uname -a | grep -i "darwin" ) ]]; then
    reportError "Wrong window! ;)" && exit
fi

# BUILD FUNCTION
function build() {
    # DIRECTORIES
    OUT_DIR=${TOOLCHAIN_HEAD}/Flash-TC/out/${1}-6.x
    case "${1}" in
        "aarch64"*)
            REPO=${HOME}/ROMs/Flash/prebuilts/gcc/linux-x86/aarch64/${1}-6.x ;;
        "arm"*)
            REPO=${HOME}/ROMs/Flash/prebuilts/gcc/linux-x86/arm/${1}-6.x ;;
    esac

    # CLEAN IT
    echoText "CLEANING REPO"

    cd ${REPO}
    git checkout n7.1.2
    git pull
    rm -rf *


    # REMOVE THE OUR DIRECTORY
    rm -rf ${OUT_DIR}


    # MOVE INTO THE SCRIPTS DIRECTORY
    cd ${SCRIPTS_DIR}


    # CHECK AND SEE IF WE ARE ON ARCH
    # IF SO, ACTIVARE A VIRTUAL ENVIRONMENT FOR PROPER PYTHON SUPPORT
    if [[ -f /etc/arch-release ]]; then
        virtualenv2 ${HOME}/venv && source ${HOME}/venv/bin/activate
    fi

    # RUN THE BUILD SCRIPT
    echoText "BUILDING TOOLCHAIN"

    bash ${1}-6.x | tee -a ${LOGDIR}/Compilation/GCC/${1}-6.x-$(TZ=MST date +"%Y%m%d-%H%M").log


    # DEACTIVATE VENV IF ON ARCH
    if [[ -f /etc/arch-release ]]; then
        deactivate && rm -rf ${HOME}/venv
    fi


    # MOVE THE COMPLETED TOOLCHAIN
    cp -r ${OUT_DIR}/* ${REPO}


    # COMMIT AND PUSH THE RESULT
    echoText "PUSHING NEW TOOLCHAIN"

    cd ${REPO}/bin
    VERSION=$( ./${1}-gcc --version | grep ${1} | cut -d ' ' -f 3 )
    GCC_DATE=$( ./${1}-gcc --version | grep ${1} | cut -d ' ' -f 4 )
    HOST_GCC_VERSION=$( gcc --version | awk '/gcc/ {print $3}' )
    HOST_GCC_DATE=$( gcc --version | awk '/gcc/ {print $4}' )
    cd ..
    git add .
    git commit --signoff -m "${1} ${VERSION}: ${GCC_DATE}

Compiled on $( source /etc/os-release; echo ${PRETTY_NAME} ) $( uname -m )

Kernel version: $( uname -rv )
gcc version: ${HOST_GCC_VERSION} ${HOST_GCC_DATE}
Make version: $( make --version  | awk '/Make/ {print $3}' )

Full source: https://github.com/Flash-TC" && git push --force

}


##################
#                #
#  SCRIPT START  #
#                #
##################

clear && START=$( TZ=MST date +%s )

# INIT THE REPOS IF IT DOESN'T EXISTS
if [[ ! -d ${TOOLCHAIN_HEAD}/Flash-TC ]]; then
    echoText "RUNNING REPO INIT"

    mkdir -p ${TOOLCHAIN_HEAD}/Flash-TC
    cd ${TOOLCHAIN_HEAD}/Flash-TC
    repo init -u https://github.com/Flash-TC/manifest -b gcc
else
    cd ${TOOLCHAIN_HEAD}/Flash-TC
fi


# SYNC THE REPOS
echoText "SYNCING REPO"

repo sync --force-sync -j$( nproc --all )


# ADD THE GCC UPSTREAM REPO IF IT DOESN'T EXIST
echoText "CHECKING OUT CORRECT GCC BRANCH"

cd gcc/gcc-flash && git checkout 6.x && git reset --hard HEAD

if [[ ! $( git ls-remote --exit-code gcc 2>/dev/null ) ]]; then
    echoText "ADDING GCC REMOTE"

    git remote add gcc git://gcc.gnu.org/git/gcc.git
fi


# UPDATE GCC
echoText "UPDATING GCC"

git pull gcc gcc-6-branch --rebase
git push --force


# ADD THE BINUTILS UPSTREAM REPO IF IT DOESN'T EXIST
echoText "CHECKING OUT CORRECT BINUTILS BRANCH"

cd ../../binutils/binutils-flash && git checkout 2.27

if [[ ! $( git ls-remote --exit-code upstream 2>/dev/null ) ]]; then
    echoText "ADDING BINUTILS REMOTE"

    git remote add upstream git://sourceware.org/git/binutils-gdb.git
fi


# UPDATE BINUTILS
echoText "UPDATING BINUTILS"

git pull upstream binutils-2_27-branch --rebase
git push --force


# BUILD THE TOOLCHAINS
echoText "RUNNING BUILD SCRIPTS"

build "aarch64-linux-android"
build "arm-linux-androideabi"
build "arm-eabi"


######################
# ENDING INFORMATION #
######################

END=$( TZ=MST date +%s )

# PRINT THE TIME THE SCRIPT FINISHED
# AND HOW LONG IT TOOK REGARDLESS OF SUCCESS
newLine; echoText "SCRIPT COMPLETED"; newLine
echo -e ${RED}"TIME: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
echo -e "DURATION: $( format_time ${END} ${START} )"${RST}; newLine

# LOG INFO
echo -e "\n$( TZ=MST date +"%m/%d/%Y %H:%M:%S" ): ${BASH_SOURCE}" >> ${LOG}
echo -e "$( format_time ${END} ${START} )" >> ${LOG}
