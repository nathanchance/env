#!/bin/bash


# -----
# Usage
# -----
# $ . kylo_all.sh <tcupdate|notcupdate>
# Parameter 1: Update the toolchains used to compile by running the update_toolchains script


if [ "${1}" == "tcupdate" ]
then
   . sync_toolchains.sh
fi
. kylo.sh aosp
. kylo.sh uber4
. kylo.sh uber5
. kylo.sh uber6
. kylo.sh uber7
. kylo.sh linaro4.9
. kylo.sh linaro5.4
. kylo.sh linaro6.1
. kylo.sh df-linaro4.9
. kylo.sh df-linaro5.4
. kylo.sh df-linaro6.1


cat ${COMPILE_LOG}
cd ${HOME}
