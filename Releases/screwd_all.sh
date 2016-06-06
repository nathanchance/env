#!/bin/bash



. screwd.sh angler sync
. screwd.sh shamu sync
. screwd.sh bullhead sync
. screwd.sh hammerhead sync



cd ${LOGDIR}
cat ${COMPILE_LOG}
cd ${HOME}
