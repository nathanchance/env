#!/bin/bash


cd ${HOME}/Kernels/Toolchains


rm -rf UBER4
git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-4.9-kernel.git UBER4

rm -rf UBER5
git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-5.x-kernel.git UBER5

rm -rf UBER6
git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-6.x-kernel.git UBER6

rm -rf UBER7
git clone https://bitbucket.org/DespairFactor/aarch64-linux-android-7.0-kernel.git UBER7


cd ${HOME}
