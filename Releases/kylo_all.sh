#!/bin/bash


# -----
# Usage
# -----
# $ . kylo_all.sh <tcupdate|notcupdate> <update|noupdate>
# Parameter 1: Update the toolchains used to compile by running the update_toolchains script
# Parameter 2: Update the git repo of the kernel before compiling


if [ "${1}" == "tcupdate" ]
then
   . update_toolchains.sh
fi
. kylo.sh ${2} aosp
. kylo.sh ${2} uber4
. kylo.sh ${2} uber5
. kylo.sh ${2} uber6
. kylo.sh ${2} uber7
. kylo.sh ${2} linaro4.9
. kylo.sh ${2} linaro5.3
. kylo.sh ${2} linaro6.1


cat ${COMPILE_LOG}
cd ${HOME}
