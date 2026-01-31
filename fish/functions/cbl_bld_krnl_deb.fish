#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_bld_krnl_deb -d "Build a .deb kernel package"
    __in_container_msg -c; or return
    __in_tree kernel; or return

    # Effectively 'distclean'
    git cl -q

    # Allow cross compiling
    for arg in $argv
        switch $arg
            case aarch64 arm64
                set arch arm64
            case amd64 x86_64
                set arch x86_64
            case --cfi --cfi-permissive --lto --no-werror
                set -a config_args $arg
        end
    end

    # If no arch value specified, use host architecture
    if not set -q arch
        set arch (uname -m)
        switch $arch
            case aarch64
                set arch arm64
        end
    end

    cbl_gen_ubuntuconfig $config_args $arch

    kmake \
        ARCH=$arch \
        HOSTCFLAGS=-Wno-deprecated-declarations \
        KBUILD_BUILD_HOST=$hostname \
        LLVM=1 \
        $KMAKE_DEB_ARGS \
        O=(tbf)/$arch \
        olddefconfig bindeb-pkg; or return

    echo Run
    printf '\n\t$ run0 fish -c "dpkg -i %s; and reboot"\n\n' (realpath -- (tbf)/linux-image-*.deb | string replace $TMP_BUILD_FOLDER \$TMP_BUILD_FOLDER)
    echo "to install and use new kernel."
end
