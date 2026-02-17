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

    set -e fish_trace

    set dmesg_cmd \
        klog \
        --filter \
        --level=warn+ \
        --no-bat \
        --skip-root
    $dmesg_cmd

    sleep 5

    cbl_check_sysfs_cfi &>/dev/null
    if test $status -eq 0
        $dmesg_cmd
    else
        cbl_check_sysfs_cfi
    end
end
