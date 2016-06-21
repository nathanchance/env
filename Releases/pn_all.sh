#!/bin/bash


# -----
# Usage
# -----
# $ . pn_all.sh <mod>

if [[ -n ${3} ]]
then
   . pn.sh angler sync ${3}
   . pn.sh shamu sync ${3}
   . pn.sh bullhead sync ${3}
   . pn.sh hammerhead sync ${3}
else
   . pn.sh angler sync
   . pn.sh shamu sync
   . pn.sh bullhead sync
   . pn.sh hammerhead sync
fi

cat ${COMPILE_LOG}
cd ${HOME}
