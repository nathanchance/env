#!/bin/bash


# -----
# Usage
# -----
# $ . elite_all.sh <tcupdate|notcupdate> <exp>
# Parameter 1: Update the toolchains used to compile by running the update_toolchains script
# Parameter 2: Experimental build (leave off if you want a release build)


if [ "${1}" == "tcupdate" ]; then
   . sync_toolchains.sh
fi

# If the third parameter exists
if [[ -n ${2} ]]; then
   . elite.sh aosp ${3}
   . elite.sh uber4 ${3}
   . elite.sh uber5 ${3}
   . elite.sh uber6 ${3}
   . elite.sh uber7 ${3}
   . elite.sh linaro4.9 ${3}
   . elite.sh linaro5.4 ${3}
   . elite.sh linaro6.1 ${3}
else
   . elite.sh linaro4.9
   . elite.sh aosp
   . elite.sh uber4
fi



cat ${COMPILE_LOG}
cd ${HOME}
