#!/bin/bash


# -----
# Usage
# -----
# $ . rom_all.sh <rom> <mod|custom|oms> <oms>


DEVICES="angler shamu bullhead hammerhead"

ROM=${1}
if [[ -n ${2} ]]; then
   if [[ "${ROM}" == "du" ]]; then
      . rom.sh ${ROM} bullhead alcolawl
      . rom.sh ${ROM} angler hmhb
      . rom.sh ${ROM} shamu jdizzle
   elif [[ "${ROM}" == "pn" ]]; then
      for DEVICE in ${DEVICES}; do
         if [[ -n ${3} ]]; then
            . rom.sh ${ROM} ${DEVICE} ${2} ${3}
         else
            . rom.sh ${ROM} ${DEVICE} ${2}
         fi
      done
   fi
else
   for DEVICE in ${DEVICES}; do
      . rom.sh ${ROM} ${DEVICE}
   done
fi

cat ${COMPILE_LOG}
cd ${HOME}
