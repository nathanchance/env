#!/bin/bash


# -----
# Usage
# -----
# $ . build_ak_all.sh <tcupdate|notcupdate> <update|noupdate>
# Parameter 1: Update the toolchains used to compile by running the update_toolchains script
# Parameter 2: Update the git repo of the kernel before compiling


if [ "${1}" == "tcupdate" ]
then
   . update_toolchains.sh
fi
. build_ak.sh ${2} aosp
. build_ak.sh ${2} uber4
. build_ak.sh ${2} uber5
. build_ak.sh ${2} uber6
. build_ak.sh ${2} uber7


cat ${COMPILE_LOG}
cd ${HOME}
