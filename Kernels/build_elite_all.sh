#!/bin/bash

# -----
# Usage
# -----
# $ . build_elite_all.sh <update|noupdate>



. build_elite.sh ${1} linaro4.9
. build_elite.sh ${1} aosp4.9
. build_elite.sh ${1} uber4.9
. build_elite.sh ${1} uber5.3
# . build_elite.sh ${1} uber6.0
# . build_elite.sh ${1} uber7.0
