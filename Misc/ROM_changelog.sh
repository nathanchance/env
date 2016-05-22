#!/bin/sh

# Usage:
# $ . ROM_changelog.sh <du|pnlayers|pncmte> <device> <upload|noupload> <mm/dd/yyyy>

# Parameters
ROM=${1}
DEVICE=${2}
UPLOAD=${3}
START_DATE=${4}

# Variables
START_DATE_S=`date --date="${START_DATE}" +%s`
CURRENT_DATE=`date +%m/%d/%y`
CURRENT_DATE_S=`date +%s`
ROM_DIR=~/ROMs
if [ "${ROM}" == "du" ]
then
   SOURCE_DIR=${ROM_DIR}/DU
   UPLOAD_DIR=~/shared/DU/${DEVICE}
   ROM_NAME="Dirty Unicorns"
elif [ "${ROM}" == "pnlayers" ]
then
   SOURCE_DIR=${ROM_DIR}/PN-Layers
   UPLOAD_DIR=~/shared/PN/Layers/${DEVICE}
   ROM_NAME="Pure Nexus Layers"
elif [ "${ROM}" == "pncmte" ]
then
   SOURCE_DIR=${ROM_DIR}/PN-CMTE
   UPLOAD_DIR=~/shared/PN/CMTE/${DEVICE}
   ROM_NAME="Pure Nexus CMTE"
fi

# Terminal colors
BLDRED="\033[1m""\033[31m"
RST="\033[0m"

# Changelog file format
CHANGELOG=Changelog.txt

# Setup changelog
cd ${SOURCE_DIR}
touch ${CHANGELOG}

# Print something to build output
echo -e ${BLDRED}
echo -e ""
echo -e "Generating changelog for ${ROM_NAME}..." | tr [a-z] [A-Z]
echo -e ""
echo -e ${RST}

# Calculate number of days between start and end date
DATE_DIFF=$(( (${CURRENT_DATE_S} - ${START_DATE_S}) / 86400 + 1))

# Make the changelog
for i in `seq ${DATE_DIFF}`;
do
  export AFTER_DATE=`date --date="$i days ago" +%m-%d-%Y`
  k=$(expr $i - 1)
  export UNTIL_DATE=`date --date="$k days ago" +%m-%d-%Y`

	# Line with after --- until was too long for a small ListView
	echo '====================' >> ${CHANGELOG};
	echo  "     "${UNTIL_DATE}    >> ${CHANGELOG};
	echo '====================' >> ${CHANGELOG};
	# Cycle through every repo to find commits between 2 dates
	repo forall -pc 'git log --pretty=format:"%h  %s  [%cn]" --decorate --after=${AFTER_DATE} --until=${UNTIL_DATE}' >> ${CHANGELOG}
	echo >> ${CHANGELOG};
  echo >> ${CHANGELOG};
done

sed -i 's/project/   */g' ${CHANGELOG}

# Move the changelog
rm -rf ${UPLOAD_DIR}/${CHANGELOG}
mv ${CHANGELOG} ${UPLOAD_DIR}/${CHANGELOG}

# Upload the changelog if requested
if [ "${UPLOAD}" == "upload" ]
then
   . ~/upload.sh
fi

# Go home
cd ~/
