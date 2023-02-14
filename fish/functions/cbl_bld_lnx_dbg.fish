#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_bld_lnx_dbg -d "Build linux-debug Arch Linux package"
    in_kernel_tree; or return

    for arg in $argv
        switch $arg
            case -g --gcc
                set gcc true
            case -l --localmodconfig
                set localmodconfig true
            case -m --menuconfig
                set menuconfig true
            case -z --zero-call-used-regs
                set -a scripts_cfg_args -e ZERO_CALL_USED_REGS
            case '*'
                set -a kmake_args $arg
        end
    end

    if test "$gcc" = true
        if not string match -qr CROSS_COMPILE= $kmake_args
            set kmake_args (korg_gcc print $GCC_VERSION_STABLE x86_64)
        end
    else
        if not string match -qr LLVM= $kmake_args
            set kmake_args LLVM=1
        end
    end

    set pkg linux-debug
    set pkgroot $ENV_FOLDER/pkgbuilds/$pkg
    set pkgdir $pkgroot/pkg-ext/$pkg

    rm -fr $pkgroot/pkg{,-ext} $pkgroot/*.tar.zst

    #############
    # prepare() #
    #############
    git cl -q

    echo -debug >localversion.10-pkgname

    crl -o .config https://github.com/archlinux/svntogit-packages/raw/packages/linux/trunk/config; or return

    # Keep in sync with cbl_gen_archconfig, step 2
    scripts/config \
        $scripts_cfg_args \
        -m DRM

    kmake $kmake_args olddefconfig; or return

    if test "$localmodconfig" = true
        yes "" | kmake $kmake_args LSMOD=/tmp/modprobed.db localmodconfig; or return
    end

    if test "$menuconfig" = true
        kmake $kmake_args menuconfig; or return
    end

    make -s kernelrelease >version

    ###########
    # build() #
    ###########
    kmake $kmake_args all; or return

    #############
    # package() #
    #############
    set kernver (cat version)
    set modulesdir $pkgdir/usr/lib/modules/$kernver

    install -Dm644 (make -s image_name) $modulesdir/vmlinuz; or return
    echo "$pkg" | install -Dm644 /dev/stdin $modulesdir/pkgbase; or return
    cbl_upd_krnl_pkgver $pkg
    kmake $kmake_args DEPMOD=/doesnt/exist INSTALL_MOD_PATH=$pkgdir/usr INSTALL_MOD_STRIP=1 modules_install; or return
    rm $modulesdir/{source,build}

    pushd $pkgroot
    makepkg -R; or return
    popd

    printf '\a'
end
