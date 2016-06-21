#!/bin/bash


# -----
# Usage
# -----
# $ . aicp_all.sh


. rom_folder.sh aicp sync
. aicp.sh angler sync
. aicp.sh shamu sync
. aicp.sh bullhead sync
. aicp.sh hammerhead sync
. rom_folder.sh aicp nosync



cd ${LOGDIR}
cat ${COMPILE_LOG}
cd ${HOME}
