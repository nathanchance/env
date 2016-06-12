#!/bin/bash

# -----
# Usage
# -----
# $ . build_elite_all.sh <tcupdate|notcupdate> <update|noupdate>


if [ "${1}" == "tcupdate" ]
then
   . update_toolchains.sh
fi
. build_elite.sh ${2} linaro
. build_elite.sh ${2} aosp
. build_elite.sh ${2} uber4


cd ${LOGDIR}
cat ${COMPILE_LOG}
cd ${HOME}
