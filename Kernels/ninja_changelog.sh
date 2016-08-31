#!/bin/bash

# Version we are writing a changelog for
VERSION=${1}
# The version number we are starting the changelog from
OLD_VERSION_HASH=${2}
# The version number we are ending the changelog at
NEW_VERION_HASH=${3}

case "${VERSION}" in
   "m")
      ZIP_MOVE=${HOME}/shared/.hidden/Kernels/M ;;
   "n")
      ZIP_MOVE=${HOME}/shared/.hidden/Kernels/N ;;
   "personal")
      ZIP_MOVE=${HOME}/shared/.me ;;
esac

# Changelog name and location
CHANGELOG=${ZIP_MOVE}/ninja_changelog.txt

# Remove the previous changelog
rm -rf ${CHANGELOG}

# Move to directory and change out right branch
cd ${HOME}/Kernels/Ninja && git checkout ${VERSION}

# Generate changelog
git log ${OLD_VERSION_HASH}^..${NEW_VERION_HASH} --format="Title: %s%nAuthor: %an%nHash: %H%n" > ${CHANGELOG}

# Upload changelog
source ${HOME}/upload.sh
