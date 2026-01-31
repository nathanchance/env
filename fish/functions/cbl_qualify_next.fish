#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_qualify_next -d "Run a series of checks to qualify new linux-next revisions"
    __in_container_msg -h; or return

    request_root "dmesg and sysfs access"
    or return

    set fish_trace 1

    uname -r

    systemctl --failed

    run0 dmesg -l warn+

    sleep 5

    cbl_check_sysfs_cfi &>/dev/null
    if test $status -eq 0
        run0 dmesg -l warn,err
    else
        cbl_check_sysfs_cfi
    end
end
