#!/bin/bash


# -----
# Usage
# -----
# $ . du_all.sh <custom|normal>


TYPE=${1}


if [ "${TYPE}" == "normal" ]
then
   . du.sh angler sync
   . du.sh shamu sync
   . du.sh bullhead sync
   . du.sh hammerhead sync
elif [ "${TYPE}" == "custom" ]
then
   . du.sh angler sync drew
   . du.sh bullhead sync alcolawl
   . du.sh angler sync hmhb
   . du.sh shamu sync jdizzle
fi


cat ${COMPILE_LOG}
cd ${HOME}
