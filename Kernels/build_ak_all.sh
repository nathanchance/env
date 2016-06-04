#!/bin/bash

# -----
# Usage
# -----
# $ . build_ak_all.sh <update|noupdate>


. build_ak.sh ${1} aosp4.9
. build_ak.sh ${1} uber4
. build_ak.sh ${1} uber5
. build_ak.sh ${1} uber6
. build_ak.sh ${1} uber7
