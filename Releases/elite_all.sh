#!/bin/bash


# -----
# Usage
# -----
# $ . elite_all.sh <tcupdate|notcupdate> <update|noupdate> <exp>
# Parameter 1: Update the toolchains used to compile by running the update_toolchains script
# Parameter 2: Experimental build (leave off if you want a release build)


if [ "${1}" == "tcupdate" ]
then
   . update_toolchains.sh
fi
# If the third parameter exists
if [[ -n ${3} ]]
then
   . elite.sh update aosp ${3}
   . elite.sh update uber4 ${3}
   . elite.sh update uber5 ${3}
   . elite.sh update uber6 ${3}
   . elite.sh update uber7 ${3}
   . elite.sh update linaro4.9 ${3}
   . elite.sh update linaro5.4 ${3}
   . elite.sh update linaro6.1 ${3}
else
   . elite.sh update linaro4.9
   . elite.sh update aosp
   . elite.sh update uber4
fi



cat ${COMPILE_LOG}
cd ${HOME}
