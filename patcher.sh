#!/usr/bin/env bash
#
# ROM patcher script
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

# PURPOSE: Add patches to a ROM tree (in this case, DU)
# USAGE: Called from inside rom.sh


###############
#             #
#  VARIABLES  #
#             #
###############

REPOS="
build
device/huawei/angler
frameworks/base
system/core
system/sepolicy
vendor/du"
PATCH_FOLDER=$( dirname ${BASH_SOURCE} )/patches


###############
#             #
#  FUNCTIONS  #
#             #
###############

function add_patches() {
    for REPO in ${REPOS}; do
        cd ${SOURCE_DIR}/${REPO}
        git am --abort 2&>1 /dev/null
        git am ${PATCH_FOLDER}/${REPO}/*.patch
    done
}

function rm_patches() {
    for REPO in ${REPOS}; do
        NUM_PATCHES=$( find ${PATCH_FOLDER}/${REPO} -type f | wc -l )
        cd ${SOURCE_DIR}/${REPO}
        git clean -fxd && git reset --hard HEAD~${NUM_PATCHES}
    done
}

function add_hosts() {
    cd ${SOURCE_DIR}/system/core/rootdir/etc
    rm hosts
    wget https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts
    cd ${SOURCE_DIR}
}

function rm_hosts() {
    cd ${SOURCE_DIR}/system/core
    git reset --hard HEAD
    cd ${SOURCE_DIR}
}


#################
#               #
#  RUN PATCHER  #
#               #
#################

case ${1} in
    "add")
        add_patches
        add_hosts ;;
    "rm")
        rm_patches
        rm_hosts ;;
esac
