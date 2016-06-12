#!/bin/bash

# -----
# Usage
# -----
# $ . build_kylo_all.sh <tcupdate|notcupdate> <update|noupdate>


if [ "${1}" == "tcupdate" ]
then
   . update_toolchains.sh
fi
. build_kylo.sh ${2} aosp4.9
. build_kylo.sh ${2} uber4
. build_kylo.sh ${2} uber5
. build_kylo.sh ${2} uber6
. build_kylo.sh ${2} uber7


cd ${LOGDIR}
cat ${COMPILE_LOG}
cd ${HOME}
