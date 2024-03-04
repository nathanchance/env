#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_bld_lnx_dbg -d "Build linux-debug Arch Linux package"
    in_kernel_tree; or return

    set bld (tbf)

    for arg in $argv
        switch $arg
            case --cfi
                set -a scripts_cfg_args -e CFI_CLANG
            case --cfi-permissive
                set -a scripts_cfg_args \
                    -e CFI_CLANG \
                    -e CFI_PERMISSIVE
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
            set kmake_args (korg_gcc var x86_64)
        end
    else
        if not string match -qr LLVM= $kmake_args
            set kmake_args LLVM=1
        end
    end
    set -a kmake_args O=$bld
    set make_args -s O=$bld

    set pkg linux-debug
    set pkgroot $bld/pkgbuild
    set pkgdir $pkgroot/pkg-prepared/$pkg

    #############
    # prepare() #
    #############
    git cl -q

    echo -debug >localversion.10-pkgname

    prep_config https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/raw/main/config $bld;or return

    # Keep in sync with cbl_gen_archconfig, step 2
    scripts/config \
        --file $bld/.config \
        $scripts_cfg_args \
        -m DRM

    kmake $kmake_args olddefconfig; or return

    if test "$localmodconfig" = true
        yes "" | kmake $kmake_args LSMOD=/tmp/modprobed.db localmodconfig; or return
    end

    if test "$menuconfig" = true
        kmake $kmake_args menuconfig; or return
    end

    make $make_args kernelrelease >version

    ###########
    # build() #
    ###########
    kmake $kmake_args all; or return

    #############
    # package() #
    #############
    set kernver (cat version)
    set modulesdir $pkgdir/usr/lib/modules/$kernver

    install -Dm644 $bld/(make $make_args image_name) $modulesdir/vmlinuz; or return
    echo "$pkg" | install -Dm644 /dev/stdin $modulesdir/pkgbase; or return
    ZSTD_CLEVEL=19 kmake $kmake_args DEPMOD=/doesnt/exist INSTALL_MOD_PATH=$pkgdir/usr INSTALL_MOD_STRIP=1 modules_install; or return
    rm -f $modulesdir/{source,build}

    # Call makepkg with a dynamically generated PKGBUILD
    echo 'pkgname='$pkg'
pkgver='(git describe | string replace -a - .)'
pkgrel=1
arch=(x86_64)
license=(GPL2)
options=(\'!strip\')

package() {
  pkgdesc="The Linux kernel and modules"
  depends=(coreutils kmod initramfs)
  optdepends=(\'crda: to set the correct wireless channels of your country\'
              \'linux-firmware: firmware images needed for some devices\')
  provides=(VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE)
  replaces=(virtualbox-guest-modules-arch wireguard-arch)

  local pkgroot="${pkgdir//\\/pkg\\/$pkgname/}"
  rm -fr "$pkgroot"/pkg
  mv -v "$pkgroot"/pkg-prepared "$pkgroot"/pkg
}' >$pkgroot/PKGBUILD
    fish -c "cd $pkgroot; and makepkg -R"
    set ret $status

    printf '\a'
    return $ret
end
