#!/bin/bash


# -----
# Usage
# -----
# $ . ak_all.sh <tcupdate|notcupdate>
# Parameter 1: Update the toolchains used to compile by running the update_toolchains script


if [ "${1}" == "tcupdate" ]
then
   . sync_toolchains.sh
fi
. ak.sh aosp
. ak.sh uber4
. ak.sh uber5
. ak.sh uber6
. ak.sh uber7
. ak.sh linaro4.9
. ak.sh linaro5.4
. ak.sh linaro6.1
. ak.sh df-linaro4.9
. ak.sh df-linaro5.4
. ak.sh df-linaro6.1



cat ${COMPILE_LOG}
cd ${HOME}
