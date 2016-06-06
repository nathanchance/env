#!/bin/bash



. rom_folder.sh krexus sync
. krexus.sh angler sync
. krexus.sh shamu sync
. krexus.sh bullhead sync
. krexus.sh hammerhead sync
. rom_folder.sh krexus nosync



cd ${LOGDIR}
cat ${COMPILE_LOG}
cd ${HOME}
