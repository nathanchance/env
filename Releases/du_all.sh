#!/bin/bash



. du.sh angler sync
. du.sh shamu sync
. du.sh bullhead sync
. du.sh hammerhead sync
. du_custom.sh angler sync drew
. du_custom.sh bullhead sync alcolawl
. du_custom.sh angler sync hmhb
. du_custom.sh shamu sync jdizzle



cd ${LOGDIR}
cat ${COMPILE_LOG}
cd ${HOME}
