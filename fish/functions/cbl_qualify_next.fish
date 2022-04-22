#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_qualify_next -d "Run a series of checks to qualify new linux-next revisions"
    in_container_msg -h; or return

    set fish_trace 1
    uname -r
    systemctl --failed
    sudo dmesg -l warn,err
    sleep 5
    if test (uname -m) = x86_64
        cbl_check_cfi &>/dev/null
        if test $status -ne 0
            cbl_check_cfi
        end
    else if test $LOCATION = pi
        switch (uname -m)
            case aarch64
                set arch arm64
            case armv7l
                set arch arm
        end
        cbl_upd_krnl $arch next
        and pi_clmods
    end
end
