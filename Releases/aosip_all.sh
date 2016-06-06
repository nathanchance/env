#!/bin/bash



. rom_folder.sh aosip sync
. aosip.sh angler sync
. aosip.sh shamu sync
. aosip.sh bullhead sync
. rom_folder.sh aosip nosync



cd ${LOGDIR}
cat ${COMPILE_LOG}
cd ${HOME}
