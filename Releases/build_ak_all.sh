#!/bin/bash

# -----
# Usage
# -----
# $ . build_ak_all.sh <tcupdate|notcupdate> <update|noupdate>


if [ "${1}" == "tcupdate" ]
then
   . update_toolchains.sh
fi
. build_ak.sh ${2} aosp
. build_ak.sh ${2} uber4
. build_ak.sh ${2} uber5
. build_ak.sh ${2} uber6
. build_ak.sh ${2} uber7


cd ${LOGDIR}
cat ${COMPILE_LOG}
cd ${HOME}
