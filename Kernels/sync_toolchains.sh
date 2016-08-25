#!/bin/bash


#################
##  FUNCTIONS  ##
#################
# Remove, make, and move into function
# Parameter 1: the location of the folder you want to remake
function rm_mk_cd() {
   rm -rf ${1}
   mkdir -p ${1}
   cd ${1}
}


#################
##  VARIABLES  ##
#################
ANDROID_DIR=${HOME}
TOOLCHAINS_DIR=${ANDROID_DIR}/Kernels/Toolchains


rm_mk_cd ${TOOLCHAINS_DIR}

git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 AOSP


rm_mk_cd UBER

git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-4.9-kernel.git 4.9

git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-5.x-kernel.git 5.4

git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-6.x-kernel.git 6.1

git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-7.0-kernel.git 7.0


rm_mk_cd ../Linaro

git clone https://android-git.linaro.org/git/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9-linaro.git 4.9

git clone https://android-git.linaro.org/git/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-5.4-linaro.git 5.4

git clone https://android-git.linaro.org/git/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-6.1-linaro.git 6.1

git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-4.9-kernel-linaro.git DF-4.9

git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-5.x-kernel-linaro.git DF-5.4

git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-6.x-kernel-linaro.git DF-6.1

cd ${HOME}
