#!/bin/bash

# -----
# Usage
# -----
# $ . build_kylo_all.sh <update|noupdate>


LOGDIR=${HOME}/Logs


. build_kylo.sh ${1} aosp4.9
. build_kylo.sh ${1} uber4
. build_kylo.sh ${1} uber5
. build_kylo.sh ${1} uber6
. build_kylo.sh ${1} uber7

cd ${LOGDIR}
cat ${COMPILE_LOG}

cd ${HOME}
