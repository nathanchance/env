#!/bin/bash

# Source directory
SOURCE_DIR=${HOME}/Kernels/Ninja/Kernel

# Move to source directory
cd ${SOURCE_DIR}

# Checkout proper branch
git checkout ${1}

# Set variables
CURRENT_VERSION=$( grep -r "EXTRAVERSION = -NINJA-" ${SOURCE_DIR}/Makefile | sed 's/EXTRAVERSION = -NINJA-//' )
NEXT_VERSION=v${2}

# Replace the current version with the new version
sed -i -e "s|${CURRENT_VERSION}|${NEXT_VERSION}|g" ${SOURCE_DIR}/Makefile

# Commit the new version
git add Makefile
git commit -m "NINJA: ${NEXT_VERSION}"
git push
