#!/bin/bash
#
# Uber toolchains compilation script
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
#  VARIABLES  #
#             #
###############

TOOLCHAIN_HEAD=${HOME}/Toolchains
SCRIPTS_DIR=${TOOLCHAIN_HEAD}/Uber/scripts


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

# BUILD FUNCTION
function build() {
   # DIRECTORIES
   OUT_DIR=${TOOLCHAIN_HEAD}/Uber/out/${1}-6.x
   REPO=${TOOLCHAIN_HEAD}/Prebuilts/${1}-6.x


   # IF THE REPO DIRECTORY EXISTS
   if [[ -d ${REPO} ]]; then
      # CLEAN IT
      echoText "CLEANING REPO"

      cd ${REPO}
      rm -vrf *
   else
      # OTHERWISE, CLONE IT
      echoText "CLONING REPO"

      cd ${TOOLCHAIN_HEAD}/Prebuilts
      git clone https://gitlab.com/Flash-ROM/${1}-6.x
   fi


   # REMOVE THE OUR DIRECTORY
   echoText "CLEANING OUT_DIR"

   rm -vrf ${OUT_DIR}


   # MOVE INTO THE SCRIPTS DIRECTORY
   cd ${SCRIPTS_DIR}


   # RUN THE BUILD SCRIPT
   echoText "BUILDING TOOLCHAIN"

   virtualenv2 venv && source venv/bin/activate
   bash ${1}-6.x
   deactivate && rm -rf venv


   # MOVE THE COMPLETED TOOLCHAIN
   echoText "MOVING TOOLCHAIN"

   cp -vr ${OUT_DIR}/* ${REPO}


   # COMMIT AND PUSH THE RESULT
   echoText "PUSHING NEW TOOLCHAIN"

   cd ${REPO}/bin
   VERSION=$( ./${1}-gcc --version | grep ${1} | cut -d ' ' -f 3 )
   cd ..
   git add .
   git commit --signoff -m "${1} ${VERSION}: $( date +%Y%m%d )

Compiled on $( source /etc/os-release; echo ${PRETTY_NAME} ) $( uname -m )

Kernel version: $( uname -rv )
gcc version: $( gcc --version | grep gcc | cut -d ' ' -f 3,4 )
Make version: $( make --version  | grep Make | cut -d ' ' -f 3 )

Manifest: https://github.com/Flash-ROM/manifest/tree/uber
gcc source: https://github.com/Flash-ROM/gcc
binutils source: https://github.com/Flash-ROM/binutils"

   git push --force
}


# INIT THE REPOS IF IT DOESN'T EXISTS
if [[ ! -d ${TOOLCHAIN_HEAD}/Uber ]]; then
   echoText "RUNNING REPO INIT"

   mkdir -p ${TOOLCHAIN_HEAD}/Uber
   cd ${TOOLCHAIN_HEAD}/Uber
   repo init -u https://github.com/Flash-ROM/manifest -b uber
else
   cd ${TOOLCHAIN_HEAD}/Uber
fi


# SYNC THE REPOS
echoText "SYNCING REPO"

repo sync --force-sync -j$(grep -c ^processor /proc/cpuinfo)


# ADD THE GCC UPSTREAM REPO IF IT DOESN'T EXIST
echoText "CHECKING OUT CORRECT GCC BRANCH"

cd gcc/gcc-UBER && git checkout uber-6.x

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

cd ../../binutils/binutils-uber && git checkout binutils-2_27-branch

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
build "arm-eabi"
build "arm-linux-androideabi"
