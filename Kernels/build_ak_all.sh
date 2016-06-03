#!/bin/bash

# -----
# Usage
# -----
# $ . build_ak_all.sh <update|noupdate> <clearccache|noclearccache>

if [ ${2} == "clearccache" ]
then
   ccache -C
fi
. build_ak.sh ${1} aosp4.9


if [ ${2} == "clearccache" ]
then
   ccache -C
fi
. build_ak.sh ${1} uber4.9


if [ ${2} == "clearccache" ]
then
   ccache -C
fi
. build_ak.sh ${1} uber5.3


if [ ${2} == "clearccache" ]
then
   ccache -C
fi
. build_ak.sh ${1} uber6.0


if [ ${2} == "clearccache" ]
then
   ccache -C
fi
. build_ak.sh ${1} uber7.0
