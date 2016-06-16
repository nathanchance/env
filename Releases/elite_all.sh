#!/bin/bash


# -----
# Usage
# -----
# $ . elite_all.sh <tcupdate|notcupdate> <update|noupdate> <exp>
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
   . elite.sh ${2} aosp ${3}
   . elite.sh ${2} uber4 ${3}
   . elite.sh ${2} uber5 ${3}
   . elite.sh ${2} uber6 ${3}
   . elite.sh ${2} uber7 ${3}
   . elite.sh ${2} linaro4.9 ${3}
   . elite.sh ${2} linaro5.3 ${3}
   . elite.sh ${2} linaro6.1 ${3}
else
   . elite.sh ${2} linaro4.9
   . elite.sh ${2} aosp
   . elite.sh ${2} uber4
fi



cat ${COMPILE_LOG}
cd ${HOME}
