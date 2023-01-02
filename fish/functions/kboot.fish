#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function kboot -d "Boot a kernel in QEMU"
    if not in_container; and test -z "$OC"
        print_error "This needs to be run in a container! Override this check with 'OC=1'."
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

    if test -z "$BU"
        set BU $CBL_GIT/boot-utils-ro
    end
    if not test -d "$BU"
        mkdir -p (dirname $BU)
        git clone https://github.com/ClangBuiltLinux/boot-utils $BU; or return
    end
    if test "$U" != 0
        git -C $BU pull -q -r; or return
    end

    if set -q PO
        set -p PATH $PO
    end

    set boot_qemu_cmd \
        $BU/boot-qemu.py $boot_qemu_args
    print_cmd $boot_qemu_cmd
    $boot_qemu_cmd
end
