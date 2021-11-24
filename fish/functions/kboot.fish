#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function kboot -d "Boot a kernel in QEMU"
    if test -z "$container"; and test -z "$OVERRIDE_CONTAINER"
        print_error "This needs to be run in a container!"
        return 1
    end

    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    for arg in $argv
        switch $arg
            case -k --kbuild-folder
                set kernel true
                set -a boot_qemu_args $arg

            case '*'
                set -a boot_qemu_args $arg
        end
    end

    if not set -q kernel
        set -a boot_qemu_args -k .
    end

    if test -z "$BOOT_UTILS"
        set BOOT_UTILS $CBL_GIT/boot-utils-ro
    end
    if not test -d "$BOOT_UTILS"
        mkdir -p (dirname $BOOT_UTILS)
        git clone https://github.com/ClangBuiltLinux/boot-utils $BOOT_UTILS; or return
    end
    if test "$UPDATE" != false
        git -C $BOOT_UTILS pull -q -r; or return
    end

    if test -n "$PO"
        set PO $PO:
    end

    set fish_trace 1
    $BOOT_UTILS/boot-qemu.sh $boot_qemu_args
end
