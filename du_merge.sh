#!/usr/bin/env bash
#
# Copyright (C) 2017 Nathan Chancellor
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

# PURPOSE: Merge DU updates into my personal forked repos
# USAGE: $ bash du_merge.sh -h

# PRINT A HELP MENU IF REQUESTED
if [[ -n ${1} ]]; then
    echo -e ""
    echo -e "${BOLD}OVERVIEW:${RST} Update personal Dirty Unicorns repos by fetching and merging\n"
    echo -e "${BOLD}USAGE:${RST} bash ${0}\n"
    exit
fi


###############
#             #
#  VARIABLES  #
#             #
###############

# If SOURCE_DIR isn't defined, the script is being run separately
if [[ -z ${SOURCE_DIR} ]]; then
    SOURCE_DIR=${HOME}/ROMs/DU
fi

DU_REPOS="
build
device/huawei/angler
external/skia
frameworks/base
frameworks/native
packages/apps/DUI
packages/apps/DU-Tweaks
system/core
vendor/du"


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


################
#              #
# SCRIPT START #
#              #
################

for FOLDER in ${DU_REPOS}; do
    # PRINT TO THE USER WHAT WE ARE DOING
    newLine; echoText "Updating ${FOLDER}"

    # SHIFT TO PROPER FOLDER
    cd ${SOURCE_DIR}/${FOLDER}

    # SET PROPER URL
    URL=android_$( echo ${FOLDER} | sed "s/\//_/g" )

    # FETCH AND MERGE UPSTREAM
    git pull https://github.com/DirtyUnicorns/${URL} n7x

    if [[ $? -ne 0 ]]; then
        RESULT_STRING+="${FOLDER}: ${RED}FAILED${RST}\n"
        EXIT_NEEDED=true
    else
        RESULT_STRING+="${FOLDER}: ${GRN}SUCCESS${RST}\n"

        git push nathanchance HEAD:n7x
    fi
done

# SHIFT BACK TO THE TOP OF THE REPO
cd ${SOURCE_DIR}

# PRINT RESULTS
echoText "RESULTS"
echo -e ${RESULT_STRING}

# Signal to rom.sh to exit
[[ ${EXIT_NEEDED} = true ]] && exit 1
