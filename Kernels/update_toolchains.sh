#!/bin/bash

TOOLCHAIN_DIR=~/Kernels/Toolchains/UBER

cd ${TOOLCHAIN_DIR}
repo sync --force-sync

cd scripts
source aarch64-linux-android-4.9-kernel

cd ../scripts
source aarch64-linux-android-5.3-kernel

cd ../scripts
source aarch64-linux-android-6.0-kernel

cd ../scripts
source aarch64-linux-android-7.0-kernel
