#!/bin/bash


# -----
# Usage
# -----
# $ . du_all.sh <custom|normal> <sync|nosync>


TYPE=${1}
SYNC=${2}


if [ "${TYPE}" == "normal" ]
then
   . du.sh angler ${SYNC}
   . du.sh shamu ${SYNC}
   . du.sh bullhead ${SYNC}
   . du.sh hammerhead ${SYNC}
elif [ "${TYPE}" == "custom" ]
then
   . du.sh angler ${SYNC} drew
   . du.sh bullhead ${SYNC} alcolawl
   . du.sh angler ${SYNC} hmhb
   . du.sh shamu ${SYNC} jdizzle
fi


cat ${COMPILE_LOG}
cd ${HOME}
