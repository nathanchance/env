#!/bin/bash


# -----
# Usage
# -----
# $ . screwd_all.sh


. rom_folder.sh screwd sync
. screwd.sh angler sync
. screwd.sh shamu sync
. screwd.sh bullhead sync
. screwd.sh hammerhead sync
. rom_folder.sh screwd nosync


cat ${COMPILE_LOG}
cd ${HOME}
