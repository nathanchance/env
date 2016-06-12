#!/bin/bash


# -----
# Usage
# -----
# $ . pn_all.sh


. pn.sh angler sync
. pn.sh shamu sync
. pn.sh bullhead sync
. pn.sh hammerhead sync


cat ${COMPILE_LOG}
cd ${HOME}
