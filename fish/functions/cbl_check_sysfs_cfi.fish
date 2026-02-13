#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_check_sysfs_cfi -d "Run LTP's read_all testcase and check for CFI failures"
    set read_all $ENV_FOLDER/bin/$UTS_MACH/read_all

    run0 $read_all -d /proc
    or return

    run0 $read_all -d /sys
    or return

    klog --filter --level=warn+ --no-bat --skip-root
end
