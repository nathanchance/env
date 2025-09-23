#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_bld_krnl_rpm -d "Build a .rpm kernel package"
    __in_container_msg -c; or return
    __in_tree kernel; or return

    # Effectively 'distclean'
    git cl -e .config -q

    # Allow cross compiling
    for arg in $argv
        switch $arg
            case --cfi --cfi-permissive --debug --lto --no-debug --no-werror --slim-arm64-platforms
                set -a gen_config_args $arg
            case -g --gcc
                set gcc true
            case -l --localmodconfig
                set lsmod /tmp/modprobed.db
                if not test -f $lsmod
                    __print_error "$lsmod not found!"
                    return 1
                end
                set -a kmake_args LSMOD=$lsmod
                set -a kmake_targets localmodconfig
            case -m --menuconfig
                set -a kmake_targets menuconfig
            case -n --no-config
                set config false
            case aarch64 arm64
                set arch arm64
            case amd64 x86_64
                set arch x86_64
            case '*'
                set -a kmake_args $arg
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

    if not set -q out
        set out (tbf)
    end

    if test "$config" != false
        cbl_gen_fedoraconfig $gen_config_args $arch
        or return
    end

    if set -q gcc
        if not string match -qr CROSS_COMPILE= $kmake_args
            set -a kmake_args (korg_gcc var $arch)
        end
    else
        if not string match -qr LLVM= $kmake_args
            set -a kmake_args LLVM=1
        end
    end

    set rpmopts '--without devel'
    # /, which includes /var/tmp, is idmapped, which breaks writing to it with our user, so use /tmp.
    if __in_nspawn
        set -a rpmopts "--define '_tmppath /tmp'"
    end
    if not string match -qr -- "--define='_topdir" <scripts/Makefile.package
        set -a rpmopts "--define '_topdir $out/rpmbuild'"
    end
    kmake \
        ARCH=$arch \
        $kmake_args \
        O=$out \
        RPMOPTS="$rpmopts" \
        olddefconfig $kmake_targets binrpm-pkg
    or return

    set rpm (fd -e rpm -u 'kernel-[0-9]+' $out/rpmbuild | path resolve)
    if test (count $rpm) -ne 1
        __print_error "More than one .rpm found? $rpm"
        return 1
    end

    rm -f $out/b2sum
    b2sum $rpm | string replace /run/host '' >$out/b2sum

    echo Run
    printf '\n\t$ sudo fish -c "dnf install %s; and reboot"\n\n' (string replace $TMP_BUILD_FOLDER \$TMP_BUILD_FOLDER $rpm)
    echo "to install and use new kernel."
end
