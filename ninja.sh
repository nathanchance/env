#!/usr/bin/env bash
#
# Ninja binary compilation script
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

# PURPOSE: Builds the ninja binary from source
# USAGE: $ bash ninja.sh -h

# Script needs to be run in a subshell; sourcing can break stuff
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo -e "\033[01;31m"
    echo "Script cannot be sourced, please run it with the bash command!"
    echo -e "\033[0m"
    return 0
fi


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

# PRINT A HELP MENU IF REQUESTED
function help_menu() {
    echo -e ""
    echo -e "${BOLD}OVERVIEW:${RST} Builds and pushes the ninja binary\n"
    echo -e "${BOLD}USAGE:${RST} bash ${0} <options>\n"
    echo -e "${BOLD}EXAMPLE:${RST} bash ${0} both\n"
    echo -e "${BOLD}OPTIONAL PARAMETERS (PICK ONE):${RST}"
    echo -e "   build:     update the source and builds the ninja binary"
    echo -e "   install:   pushes the binary to /usr/local/bin and updates Flash-ROM prebuilt-tools repo"
    echo -e "   both:      does both build and install\n"
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
        "build"|"install"|"both")
            MODE=${1} ;;
        "-h"|"--help")
            help_menu ;;
        *)
            reportError "Invalid parameter" -c; help_menu && exit ;;
    esac

    shift
done

if [[ -z ${MODE} ]]; then
    reportWarning "You did not specify a necessary parameter. Falling back to building only" -c
    MODE=build
fi


###############
#             #
#  VARIABLES  #
#             #
###############

NINJA_SOURCE=${HOME}/Repos/ninja
CLANG_LOCATION=${HOME}/Toolchains/Prebuilts/clang-5.0.x
ROM_SOURCE=${HOME}/ROMs/Flash


################
#              #
# SCRIPT START #
#              #
################

if [[ ${MODE} = "build" || ${MODE} = "both" ]]; then
    # BUILD A NEW BINARY
    echoText "BUILDING NINJA"
    virtualenv2 ${HOME}/venv && source ${HOME}/venv/bin/activate
    CXX=${CLANG_LOCATION}/bin/clang++ ./configure.py --bootstrap
    deactivate && rm -rf ${HOME}/venv
fi

if [[ ${MODE} = "install" || ${MODE} = "both" ]]; then
    # COPY NINJA TO /USR/BIN/LOCAL
    echoText "INSTALLING NINJA LOCALLY"
    cd ${NINJA_SOURCE}
    if [[ -f ninja ]]; then
        sudo install ninja /usr/local/bin
    else
        echo "NINJA BINARY NOT FOUND" && exit
    fi

    # COPY NINJA TO ROM SOURCE (PREBUILTS/BUILT-TOOLS)
    echoText "UPDATING NINJA IN PREBUILTS/BUILD-TOOLS"
    cd ${ROM_SOURCE}/prebuilts/build-tools
    git checkout n7.1.2
    rm -rf linux-x86/bin/ninja
    cp -v ${NINJA_SOURCE}/ninja linux-x86/bin/ninja
    git add -A && git commit --signoff -m "Ninja $( ./linux-x86/bin/ninja --version ): $( date +%Y%m%d )

Compiled on $( source /etc/os-release; echo ${PRETTY_NAME} ) $( uname -m )

Kernel version: $( uname -rv )
Clang version: $( ${CLANG_LOCATION}/bin/clang++ --version | awk '/version/ {print $3}' ) $( git -C ${CLANG_LOCATION} log -1 --format="%s" | cut -d " " -f 3 )
Make version: $( make --version  | awk '/Make/ {print $3}' )

Source: https://github.com/Flash-ROM/ninja" && git push --force

fi
