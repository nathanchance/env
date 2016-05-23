#!/bin/sh

# -----
# Usage
# -----
# $ . kernel_changelog.sh <ak|elite> <mm/dd/yyyy> <upload|noupload>



# ----------
# Parameters
# ----------
# KERNEL: Kernel name
# START_DATE: The start date of the changelog
# UPLOAD: Whether or not to upload
KERNEL=${1}
START_DATE=${2}
UPLOAD=${3}



# ---------
# Variables
# ---------
# CURRENT_DATE: The end date of the changelog
# FILE_DATE: Same as the CURRENT_DATE but formatted with _ instead of /
# UPLOAD_DIR: The upload directory for the changelog
# KERNEL_DIR: The directory of the source
# KERNEL_NAME: The name of the kernel
CURRENT_DATE=`date +"%m/%d/%Y"`
FILE_DATE=`date +"%m_%d_%Y"`
UPLOAD_DIR=~/shared/Kernels
if [ ${KERNEL} == "ak" ]
then
   KERNEL_DIR=~/Kernels/AK-Angler
   KERNEL_NAME=AK
elif [ ${KERNEL} == "elite" ]
then
   KERNEL_DIR=~/Kernels/elite_angler
   KERNEL_NAME=Elite
fi



# Remove previous changelog
rm -rf ${UPLOAD_DIR}/${KERNEL_NAME}_Changelog_*



# Check the date start range is set
if [ -z "$START_DATE" ]; then
   echo ""
   echo "ATTENTION: Start date not defined"
   echo ""
   echo " >>> Please define a start date in mm/dd/yyyy format ..."
   echo ""
   read START_DATE
fi



# Find the directories to log
echo ""
echo "${KERNEL_NAME} CHANGELOG" | tr [a-z] [A-Z]
echo ""
find ${KERNEL_DIR} -name .git | sed 's/\/.git//g' | sed 'N;$!P;$!D;$d' | while read LINE
do
   cd ${LINE}

   # Test to see if the repo needs to have a changelog written.
   LOG=$(git log --pretty="%an - %s" --no-merges --since=${START_DATE} --date-order)

   if [ -z "${LOG}" ]; then
      echo " >>> Nothing updated on ${KERNEL_NAME} Kernel changelog since ${START_DATE}, skipping ..."
   else
      # Write the changelog
      echo " >>> Changelog is updated and written for ${KERNEL_NAME} Kernel since ${START_DATE}..."
      echo "Project name: ${KERNEL_NAME} Kernel" >> "${UPLOAD_DIR}"/${KERNEL_NAME}_Changelog_${FILE_DATE}.txt
      echo "Dates: ${START_DATE} to ${CURRENT_DATE}" >> "${UPLOAD_DIR}"/${KERNEL_NAME}_Changelog_${FILE_DATE}.txt
      echo "${LOG}" | while read LINE
      do
         echo "   ${LINE}" >> "${UPLOAD_DIR}"/${KERNEL_NAME}_Changelog_${FILE_DATE}.txt
      done
      echo "" >> "${UPLOAD_DIR}"/${KERNEL_NAME}_Changelog_${FILE_DATE}.txt
   fi
done



# Upload the new changelog if requested
if [ "${UPLOAD}" == "upload" ]
then
   cd ~/
   . upload.sh
fi
