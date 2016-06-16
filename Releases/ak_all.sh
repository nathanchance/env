#!/bin/bash


# -----
# Usage
# -----
# $ . ak_all.sh <tcupdate|notcupdate> <update|noupdate>
# Parameter 1: Update the toolchains used to compile by running the update_toolchains script
# Parameter 2: Update the git repo of the kernel before compiling


if [ "${1}" == "tcupdate" ]
then
   . update_toolchains.sh
fi
. ak.sh ${2} aosp
. ak.sh ${2} uber4
. ak.sh ${2} uber5
. ak.sh ${2} uber6
. ak.sh ${2} uber7
. ak.sh ${2} linaro4.9
. ak.sh ${2} linaro5.3
. ak.sh ${2} linaro6.1


cat ${COMPILE_LOG}
cd ${HOME}
