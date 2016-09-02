#!/bin/bash

# Move to source directory
cd ${HOME}/Kernels/Ninja

# Checkout proper branch
git checkout ${1}

# Replace the current version with the new version
sed -i -e "s|$( grep -r "EXTRAVERSION = -NINJA-" Makefile | sed 's/EXTRAVERSION = -NINJA-//' )|v${2}|g" Makefile

# Commit the new version
git add Makefile
git commit -m "NINJA: v${2}"
git push
