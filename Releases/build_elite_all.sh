#!/bin/bash


# -----
# Usage
# -----
# $ . build_elite_all.sh <tcupdate|notcupdate> <update|noupdate> <exp>
# Parameter 1: Update the toolchains used to compile by running the update_toolchains script
# Parameter 2: Update the git repo of the kernel before compiling
# Parameter 3: Experimental build (leave off if you want a release build)


if [ "${1}" == "tcupdate" ]
then
   . update_toolchains.sh
fi
# If the third parameter exists
if [[ -n ${3} ]]
then
   . build_elite.sh ${2} linaro ${3}
   . build_elite.sh ${2} aosp ${3}
   . build_elite.sh ${2} uber4 ${3}
   . build_elite.sh ${2} uber5 ${3}
   . build_elite.sh ${2} uber6 ${3}
   . build_elite.sh ${2} uber7 ${3}
else
   . build_elite.sh ${2} linaro
   . build_elite.sh ${2} aosp
   . build_elite.sh ${2} uber4
fi



cat ${COMPILE_LOG}
cd ${HOME}
