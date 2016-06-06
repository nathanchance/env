#!/bin/bash



. pn.sh angler sync
. pn.sh shamu sync
. pn.sh bullhead sync
. pn.sh hammerhead sync



cd ${LOGDIR}
cat ${COMPILE_LOG}
cd ${HOME}
