#!/bin/bash

# -----
# Usage
# -----
# $ . build_elite_all.sh <update|noupdate>



. build_elite.sh ${1} linaro
. build_elite.sh ${1} aosp
. build_elite.sh ${1} uber4



cd ${LOGDIR}
cat ${COMPILE_LOG}
cd ${HOME}
