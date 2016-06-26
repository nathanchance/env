#!/bin/bash


# -----
# Usage
# -----
# $ . rom_all.sh <rom> <mod|custom>


DEVICES="angler shamu bullhead hammerhead"

ROM=${1}
if [[ -n ${2} ]]
then
   if [ "${ROM}" == "du" ]
   then
      . rom.sh ${ROM} angler sync drew
      . rom.sh ${ROM} bullhead sync alcolawl
      . rom.sh ${ROM} angler sync hmhb
      . rom.sh ${ROM} shamu sync jdizzle
   elif [ "${ROM}" == "pn" ]
   then
      for DEVICE in ${DEVICES}
      do
         . rom.sh ${ROM} ${DEVICE} sync ${2}
      done
   fi
else
   for DEVICE in ${DEVICES}
   do
      . rom.sh ${ROM} ${DEVICE} sync
   done
fi

cat ${COMPILE_LOG}
cd ${HOME}
