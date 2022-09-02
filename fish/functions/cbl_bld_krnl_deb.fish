#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_bld_krnl_deb -d "Build a .deb kernel package"
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
            case --cfi --cfi-permissive --lto
                set -a config_args $arg
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

    cbl_gen_ubuntuconfig $config_args $arch

    kmake \
        ARCH=$arch \
        HOSTCFLAGS=-Wno-deprecated-declarations \
        KBUILD_BUILD_HOST=(uname -n) \
        LLVM=1 \
        $KMAKE_DEB_ARGS \
        O=.build/$arch \
        olddefconfig bindeb-pkg; or return

    echo Run
    printf '\n\t$ sudo fish -c "dpkg -i %s; and reboot"\n\n' (realpath -- .build/linux-image-*.deb | string replace $HOME \$HOME)
    echo "to install and use new kernel."
end
