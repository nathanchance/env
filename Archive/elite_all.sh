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

TOOLCHAINS="aosp uber4 uber5 uber6 uber7 linaro4.9 linaro5.4 linaro6.1 df-linaro4.9 df-linaro5.4 df-linaro6.1"

# If the third parameter exists
if [[ -n ${2} ]]; then
   for TOOLCHAIN in ${TOOLCHAINS}; do
      . elite.sh ${TOOLCHAIN} ${2}
   done
else
   . elite.sh linaro4.9
   . elite.sh aosp
   . elite.sh uber4
fi



cat ${COMPILE_LOG}
cd ${HOME}
