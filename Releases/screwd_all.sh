#!/bin/bash


. rom_folder.sh screwd sync
. screwd.sh angler sync
. screwd.sh shamu sync
. screwd.sh bullhead sync
. screwd.sh hammerhead sync
. rom_folder.sh screwd nosync


cd ${LOGDIR}
cat ${COMPILE_LOG}
cd ${HOME}
