#!/bin/bash
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

# PURPOSE: Merge LineageOS updates into LineageOMS org
# USAGE: $ bash lineage_merge.sh


###############
#             #
#  VARIABLES  #
#             #
###############

SOURCE_DIR=${HOME}/ROMs/Lineage

SUBS_REPOS="
.repo/manifests
frameworks/base
frameworks/native
packages/apps/Contacts
packages/apps/ContactsCommon
packages/apps/Dialer
packages/apps/ExactCalculator
packages/apps/PackageInstaller
packages/apps/PhoneCommon
packages/apps/Settings
system/core
system/sepolicy
vendor/cm"


############
#          #
#  COLORS  #
#          #
############

GREEN="\033[01;32m"
RED="\033[01;31m"
RESTORE="\033[0m"


###############
#             #
#  FUNCTIONS  #
#             #
###############

# SOURCE OUR UNIVERSAL FUNCTIONS SCRIPT
source $( dirname ${BASH_SOURCE} )/funcs.sh


################
#              #
# SCRIPT START #
#              #
################

# START TRACKING TIME
START=$( date +%s )

for FOLDER in ${SUBS_REPOS}; do
    # PRINT TO THE USER WHAT WE ARE DOING
    newLine; echoText "Updating ${FOLDER}"

    # SHIFT TO PROPER FOLDER
    cd ${SOURCE_DIR}/${FOLDER}

    # CHECKOUT THE RIGHT BRANCH
    git checkout cm-14.1

    # SET PROPER URL
    if [[ ${FOLDER} = ".repo/manifests" ]]; then
        URL=android
    else
        URL=android_$( echo ${FOLDER} | sed "s/\//_/g" )
    fi

    # FETCH THE REPO
    git fetch https://github.com/LineageOS/${URL} cm-14.1

    # REBASE ON FETCH_HEAD
    git rebase FETCH_HEAD

    # ADD TO RESULT STRING
    if [[ $? -ne 0 ]]; then
        RESULT_STRING+="${FOLDER}: ${RED}FAILED${RESTORE}\n"
    else
        RESULT_STRING+="${FOLDER}: ${GREEN}SUCCESS${RESTORE}\n"

        git push --force
    fi
done

# SHIFT BACK TO THE TOP OF THE REPO
cd ${SOURCE_DIR}

# SYNC THEME INTERFACER REPO
newLine; echoText "Syncing packages/apps/ThemeInterfacer"
repo sync --force-sync packages/apps/ThemeInterfacer

# PRINT RESULTS
echoText "RESULTS"
echo -e ${RESULT_STRING}

# STOP TRACKING TIME
END=$( date +%s )

# PRINT RESULT TO USER
echoText "SCRIPT COMPLETED!"
echo -e ${RED}"TIME: $(format_time ${END} ${START})"${RESTORE}; newLine
