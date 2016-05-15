#!/bin/bash

# Usage:
# $ . pn_layers.sh <device> <sync|nosync>
# Parameter 1: device (eg. angler, bullhead, shamu)
# Parameter 2: sync or nosync (decides whether or not to run repo sync)

# Examples:
# . pn_layers.sh angler sync
# . pn_layers.sh angler nosync

# Colors
BLDBLUE="\033[1m""\033[36m"
RST="\033[0m"

# Variables
SOURCEDIR=~/ROMs/PN-Layers
OUTDIR=${SOURCEDIR}/out/target/product
UPLOADDIR=~/shared/PN/Layers

# Parameters
DEVICE=$1
SYNC=$2

# Start tracking time
echo -e ""
echo -e ${BLDBLUE}"SCRIPT STARTING AT $(date +%D\ %r)"${RST}
echo -e ""
START=$(date +%s)

# Change to the source directory
echo -e ${BLDBLUE}"MOVING TO ${SOURCEDIR}"${RST}
echo -e ""
cd ${SOURCEDIR}

# Sync the repo if requested
if [ "${SYNC}" == "sync" ]
then
   echo -e ${BLDBLUE}"SYNCING LATEST SOURCES"${RST}
   echo -e ""
   repo sync
fi

# Setup the build environment
echo -e ${BLDBLUE}"SETTING UP BUILD ENVIRONMENT"${RST}
echo -e ""
. build/envsetup.sh
echo -e ""

# Prepare device
echo -e ${BLDBLUE}"PREPARING ${DEVICE}"${RST}
echo -e ""
breakfast ${DEVICE}

# Clean up
echo -e ${BLDBLUE}"CLEANING UP ${SOURCEDIR}/out"${RST}
echo -e ""
make clean
make clobber

# Start building
echo -e ${BLDBLUE}"MAKING ZIP FILE"${RST}
echo -e ""
mka bacon
echo -e ""

# Remove exisiting files in UPLOADDIR
echo -e ${BLDBLUE}"REMOVING FILES IN ${UPLOADDIR}"${RST}
echo -e ""
rm ${UPLOADDIR}/*_${DEVICE}_*.zip
rm ${UPLOADDIR}/*_${DEVICE}_*.zip.md5sum

# Copy new files to UPLOADDIR
echo -e ${BLDBLUE}"MOVING FILES FROM ${OUTDIR} TO ${UPLOADDIR}"${RST}
echo -e ""
mv ${OUTDIR}/${DEVICE}/pure_nexus_${DEVICE}-*.zip ${UPLOADDIR}
mv ${OUTDIR}/${DEVICE}/pure_nexus_${DEVICE}-*.zip.md5sum ${UPLOADDIR}

# Upload the files
echo -e ${BLDBLUE}"UPLOADING FILES"${RST}
echo -e ""
. ~/upload.sh
echo -e ""

# Clean up out directory to free up space
echo -e ${BLDBLUE}"CLEANING UP ${SOURCEDIR}/out"${RST}
echo -e ""
make clean
make clobber

# Go back home
echo -e ${BLDBLUE}"GOING HOME"${RST}
echo -e ""
cd ~/

# Stop tracking time
echo -e ${BLDBLUE}"SCRIPT ENDING AT $(date +%D\ %r)"${RST}
echo -e ""
END=$(date +%s)

# Successfully completed compilation
echo -e ${BLDBLUE}"====================================="${RST}
echo -e ${BLDBLUE}"Compilation and upload successful!"${RST}
echo -e ${BLDBLUE}"Total time elapsed: $(echo $(($END-$START)) | awk '{print int($1/60)"mins "int($1%60)"secs"}')"${RST}
echo -e ${BLDBLUE}"====================================="${RST}
