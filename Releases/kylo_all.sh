#!/bin/bash


# -----
# Usage
# -----
# $ . kylo_all.sh <tcupdate|notcupdate>
# Parameter 1: Update the toolchains used to compile by running the update_toolchains script


if [ "${1}" == "tcupdate" ]
then
   . update_toolchains.sh
fi
. kylo.sh update aosp
. kylo.sh update uber4
. kylo.sh update uber5
. kylo.sh update uber6
. kylo.sh update uber7
. kylo.sh update linaro4.9
. kylo.sh update linaro5.4
. kylo.sh update linaro6.1
. kylo.sh update df-linaro4.9
. kylo.sh update df-linaro5.4
. kylo.sh update df-linaro6.1


cat ${COMPILE_LOG}
cd ${HOME}
