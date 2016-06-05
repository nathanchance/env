#!/bin/bash

LOGDIR=${HOME}/Logs

. du.sh angler sync
. du.sh shamu sync
. du_custom.sh bullhead sync alcolawl
. du_custom.sh angler sync hmhb
. du_custom.sh shamu sync jdizzle

cd ${LOGDIR}
cat ${COMPILE_LOG}

cd ${HOME}
