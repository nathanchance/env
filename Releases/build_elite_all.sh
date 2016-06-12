#!/bin/bash

# -----
# Usage
# -----
# $ . build_elite_all.sh <tcupdate|notcupdate> <update|noupdate>
# Parameter 1: Update the toolchains used to compile by running the update_toolchains script
# Parameter 2: Update the git repo of the kernel before compiling


if [ "${1}" == "tcupdate" ]
then
   . update_toolchains.sh
fi
. build_elite.sh ${2} linaro
. build_elite.sh ${2} aosp
. build_elite.sh ${2} uber4


cat ${COMPILE_LOG}
cd ${HOME}
