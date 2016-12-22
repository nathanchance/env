#!/bin/bash
#
# Ninja binary compilation script
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
      "build"|"install"|"both")
         MODE=${1} ;;
      *)
         echo "Invalid parameter" && exit ;;
   esac

   shift
done

if [[ -z ${MODE} ]]; then
   echo "You did not specify a necessary parameter. Falling back to building only"
   MODE=build
fi


###############
#             #
#  VARIABLES  #
#             #
###############

NINJA_SOURCE=${HOME}/Repos/ninja
CLANG_LOCATION=${HOME}/Toolchains/Prebuilts/clang-3.9.1
ROM_SOURCE=${HOME}/ROMs/Flash7.1.1


################
#              #
# SCRIPT START #
#              #
################

if [[ "${MODE}" == "build" || "${MODE}" == "both" ]]; then
   # CLEANING
   echoText "CLEANING REPO"
   rm -rf ${NINJA_SOURCE}
   cd $( dirname ${NINJA_SOURCE} )
   git clone https://github.com/Flash-ROM/ninja


   # UPDATE WITH UPSTREAM
   echoText "UPDATING NINJA SOURCE"
   cd ninja
   git remote add upstream https://github.com/ninja-build/ninja
   git pull upstream release --rebase
   git push --force


   # BUILD A NEW BINARY
   echoText "BUILDING NINJA"
   virtualenv2 venv && source venv/bin/activate
   CXX=${CLANG_LOCATION}/bin/clang++ ./configure.py --bootstrap
   deactivate && rm -rf venv
fi

if [[ "${MODE}" == "install" || "${MODE}" == "both" ]]; then
   # COPY NINJA TO /USR/BIN/LOCAL
   echoText "INSTALLING NINJA LOCALLY"
   cd ${NINJA_SOURCE}
   if [[ -f ninja ]]; then
      sudo mkdir -p /usr/local/bin
      sudo cp -v ninja /usr/local/bin
      sudo chmod +x /usr/local/bin/ninja
   else
      echo "NINJA BINARY NOT FOUND" && exit
   fi

   # COPY NINJA TO ROM SOURCE (PREBUILTS/NINJA)
   echoText "UPDATING NINJA IN PREBUILTS/NINJA"
   cd ${ROM_SOURCE}/prebuilts/ninja/linux-x86
   git checkout n7.1.1
   rm -rf ninja
   cp -v ${NINJA_SOURCE}/ninja .
   git add -A && git commit --signoff -m "Ninja $( ./ninja --version ): $( date +%Y%m%d )

Compiled on $( source /etc/os-release; echo ${PRETTY_NAME} ) $( uname -m )

Kernel version: $( uname -rv )
Clang version: $( ${CLANG_LOCATION}/bin/clang++ --version | grep version | cut -d ' ' -f 3 )
Make version: $( make --version  | grep Make | cut -d ' ' -f 3 )

Source: https://github.com/Flash-ROM/ninja" && git push --force

   # COPY NINJA TO ROM SOURCE (PREBUILTS/BUILT-TOOLS)
   echoText "UPDATING NINJA IN PREBUILTS/BUILD-TOOLS"
   cd ${ROM_SOURCE}/prebuilts/build-tools
   git checkout n7.1.1
   rm -rf linux-x86/asan/bin/ninja
   rm -rf linux-x86/bin/ninja
   cp -v ${NINJA_SOURCE}/ninja linux-x86/asan/bin/ninja
   cp -v ${NINJA_SOURCE}/ninja linux-x86/bin/ninja
   git add -A && git commit --signoff -m "Ninja $( ./linux-x86/bin/ninja --version ): $( date +%Y%m%d )

Compiled on $( source /etc/os-release; echo ${PRETTY_NAME} ) $( uname -m )

Kernel version: $( uname -rv )
Clang version: $( ${CLANG_LOCATION}/bin/clang++ --version | grep version | cut -d ' ' -f 3 )
Make version: $( make --version  | grep Make | cut -d ' ' -f 3 )

Source: https://github.com/Flash-ROM/ninja" && git push --force

fi
