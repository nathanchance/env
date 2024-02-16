#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_qualify_next -d "Run a series of checks to qualify new linux-next revisions"
    in_container_msg -h; or return
    sudo true; or return

    set fish_trace 1

    uname -r

    systemctl --failed

    sudo dmesg -l warn,err

    sleep 5

    cbl_check_sysfs_cfi &>/dev/null
    if test $status -eq 0
        sudo dmesg -l warn,err
    else
        cbl_check_sysfs_cfi
    end

    if test $LOCATION = pi; and test (get_distro) = debian
        set -e fish_trace
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
