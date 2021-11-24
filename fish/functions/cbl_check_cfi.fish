#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_check_cfi -d "Run LTP's read_all testcase and check for CFI failures"
    cbl_clone_repo boot-utils

    set read_all $CBL_GIT/boot-utils/debian/ltp/testcases/kernel/fs/read_all/read_all

    if not test -x $read_all
        podcmd $CBL_GIT/boot-utils/debian/ltp.sh; or return
    end

    sudo true; or return

    sudo sh -c "dmesg -C && $read_all -d /proc && $read_all -d /sys && dmesg -l warn"
end
