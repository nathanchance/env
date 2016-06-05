#!/bin/bash

cd ${HOME}/Kernels/Toolchains/UBER4
git clean -f -d
git reset --hard
git pull

cd ../UBER5
git clean -f -d
git reset --hard
git pull

cd ../UBER6
git clean -f -d
git reset --hard
git pull

cd ../UBER7
git clean -f -d
git reset --hard
git pull

cd ${HOME}
