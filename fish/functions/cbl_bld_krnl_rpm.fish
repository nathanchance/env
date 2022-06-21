#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_bld_krnl_rpm -d "Build a .rpm kernel package"
    in_container_msg -c; or return
    in_kernel_tree; or return

    # Effectively 'distclean'
    git cl -q

    # Allow cross compiling
    for arg in $argv
        switch $arg
            case aarch64 arm64
                set arch arm64
            case amd64 x86_64
                set arch x86_64
        end
    end

    # If no arch value specified, use host architecture
    if not set -q arch
        switch (uname -m)
            case aarch64
                set arch arm64
            case '*'
                set arch (uname -m)
        end
    end

    cbl_gen_fedoraconfig $arch

    kmake \
        ARCH=$arch \
        LLVM=1 \
        RPMOPTS="--define '_topdir $PWD/rpmbuild'" \
        olddefconfig binrpm-pkg; or return

    echo Run
    printf '\n\t$ sudo fish -c "dnf install %s; and reboot"\n\n' (realpath -- (fd -e rpm 'kernel-[0-9]+') | string replace $HOME \$HOME)
    echo "to install and use new kernel."
end
