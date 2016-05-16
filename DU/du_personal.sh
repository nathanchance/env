#!/bin/bash

# Usage:
# $ . du_personal.sh <device> <sync|nosync> <person>
# Parameter 1: device (eg. angler, bullhead, shamu)
# Parameter 2: sync or nosync (decides whether or not to run repo sync)

# Examples:
# . du_personal.sh shamu sync jdizzle
# . du_personal.sh angler nosync bre

# Parameters
DEVICE=$1
SYNC=$2
PERSON=$3

# Variables
SOURCEDIR=~/ROMs/DU
OUTDIR=${SOURCEDIR}/out/target/product/${DEVICE}
UPLOADDIR=~/shared/.special/.${PERSON}

# Colors
BLDRED="\033[1m""\033[31m"
RST="\033[0m"

# Add custom build tag
if [ "${PERSON}" == "bre" ]
then
   export DU_BUILD_TYPE=BREYANA
elif [ "${PERSON}" == "jdizzle" ]
then
   export DU_BUILD_TYPE=NINJA
elif [ "${PERSON}" == "alcolawl" ]
then
  export DU_BUILD_TYPE=ALCOLAWL
elif [ "${PERSON}" == "kuba" ]
then
  export DU_BUILD_TYPE=KUCKFUBA
elif [ "${PERSON}" == "hmhb" ]
then
  export DU_BUILD_TYPE=DIRTY-DEEDS
else
  export DU_BUILD_TYPE=CHANCELLOR
fi

# Start tracking time
echo -e ""
echo -e ${BLDRED}"SCRIPT STARTING AT $(date +%D\ %r)"${RST}
echo -e ""
START=$(date +%s)

# Change to the source directory
echo -e ${BLDRED}"MOVING TO ${SOURCEDIR}"${RST}
echo -e ""
cd ${SOURCEDIR}

# Sync the repo if requested
if [ "${SYNC}" == "sync" ]
then
   echo -e ${BLDRED}"SYNCING LATEST SOURCES"${RST}
   echo -e ""
   repo sync
fi

# Setup the build environment
echo -e ${BLDRED}"SETTING UP BUILD ENVIRONMENT"${RST}
echo -e ""
. build/envsetup.sh
echo -e ""

# Prepare device
echo -e ${BLDRED}"PREPARING ${DEVICE}"${RST}
echo -e ""
breakfast ${DEVICE}

# Clean up
echo -e ${BLDRED}"CLEANING UP ${SOURCEDIR}/out"${RST}
echo -e ""
make clean
make clobber

# Start building
echo -e ${BLDRED}"MAKING ZIP FILE"${RST}
echo -e ""
mka bacon
echo -e ""

# Remove exisiting files in UPLOADDIR
echo -e ${BLDRED}"REMOVING FILES IN ${UPLOADDIR}"${RST}
echo -e ""
rm ${UPLOADDIR}/*_${DEVICE}_*.zip
rm ${UPLOADDIR}/*_${DEVICE}_*.zip.md5sum

# Copy new files to UPLOADDIR
echo -e ${BLDRED}"MOVING FILES FROM ${OUTDIR} TO ${UPLOADDIR}"${RST}
echo -e ""
mv ${OUTDIR}/DU_${DEVICE}_*.zip ${UPLOADDIR}
mv ${OUTDIR}/DU_${DEVICE}_*.zip.md5sum ${UPLOADDIR}

# Upload the files
echo -e ${BLDRED}"UPLOADING FILES"${RST}
echo -e ""
. ~/upload.sh
echo -e ""

# Clean up out directory to free up space
echo -e ${BLDRED}"CLEANING UP ${SOURCEDIR}/out"${RST}
echo -e ""
make clean
make clobber

# Go back home
echo -e ${BLDRED}"GOING HOME"${RST}
echo -e ""
cd ~/

# Set DU_BUILD_TYPE back to its standard
export DU_BUILD_TYPE=CHANCELLOR

# Stop tracking time
echo -e ${BLDRED}"SCRIPT ENDING AT $(date +%D\ %r)"${RST}
echo -e ""
END=$(date +%s)

# Successfully completed compilation
echo -e ${BLDRED}"====================================="${RST}
echo -e ${BLDRED}"Compilation and upload successful!"${RST}
echo -e ${BLDRED}"Total time elapsed: $(echo $(($END-$START)) | awk '{print int($1/60)"mins "int($1%60)"secs"}')"${RST}
echo -e ${BLDRED}"====================================="${RST}
