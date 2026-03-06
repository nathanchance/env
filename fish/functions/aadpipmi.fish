#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function aadpipmi -d "Wrapper for ipmitool for interacting with AADP BMC"
    if not set -q aadp_bmc_pass
        read -g -P 'BMC password: ' -s aadp_bmc_pass
    end
    ipmitool \
        -C 17 \
        -I lanplus \
        -H 10.0.1.36 \
        -U root \
        -P $aadp_bmc_pass \
        $argv
end
