#!/bin/bash

ANDROID_DIR=${HOME}
TOOLCHAINS_DIR=${ANDROID_DIR}/Kernels/Toolchains


cd ${TOOLCHAINS_DIR}


rm -rf AOSP
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 AOSP


cd ${TOOLCHAINS_DIR}/UBER

rm -rf 4.9
git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-4.9-kernel.git 4.9

rm -rf 5.4
git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-5.x-kernel.git 5.4

rm -rf 6.1
git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-6.x-kernel.git 6.1

rm -rf 7.0
git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-7.0-kernel.git 7.0


cd ${TOOLCHAINS_DIR}/Linaro

rm -rf 4.9
git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-4.9-kernel-linaro.git 4.9
# git clone	https://android-git.linaro.org/git/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9-linaro.git 4.9

rm -rf 5.3
git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-5.x-kernel-linaro.git 5.3
# git clone	https://android-git.linaro.org/git/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-5.3-linaro.git 5.3

rm -rf 6.1
git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-6.x-kernel-linaro.git 6.1
# git clone https://android-git.linaro.org/git/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-6.1-linaro.git 6.1

cd ${HOME}
