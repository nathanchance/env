#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_check_cfi -d "Run LTP's read_all testcase and check for CFI failures"
    set read_all $ENV_FOLDER/bin/(uname -m)/read_all

    sudo sh -c "dmesg -C && $read_all -d /proc && $read_all -d /sys && dmesg -l warn"
end
