#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_bld_krnl_pkg -d "Build ClangBuiltLinux Arch Linux kernel package"
    for arg in $argv
        switch $arg
            case -f --full -l --local -m --menuconfig
                set -a config_args $arg
            case -p --permissive
                set -a config_args --cfi-permissive
            case '*'cfi '*'debug '*'mainline'*' '*'next'*'
                set pkg linux-(string replace 'linux-' '' $arg)
        end
    end
    if not set -q pkg
        set pkg linux-mainline-llvm
    end

    set pkgroot $ENV_FOLDER/pkgbuilds/$pkg

    pushd $pkgroot; or return

    # Prerequisite: Clean up old kernels
    rm -- *.tar.zst

    # Generate .config
    if test $pkg = linux-cfi
        set -a config_args --cfi
    end
    cbl_gen_archconfig $config_args $pkg

    # Update the pkgver if using a local tree
    if not grep -Fq "source=(" PKGBUILD
        cbl_upd_krnl_pkgver (basename $PWD)
    end

    # Build the kernel
    pushd src/$pkg; or return
    echo "Setting version..."
    scripts/setlocalversion --save-scmversion
    set pkg_arr (string split '-' $pkg)
    echo "-$pkg_arr[-1]" >localversion.10-pkgname

    for patch in $pkgroot/*.patch
        echo "Applying $patch..."
        patch -Np1 <"$patch"; or return
    end

    echo "Applying patches from web..."

    switch $pkg
        case linux-mainline-llvm
            # https://lore.kernel.org/r/YcC1CobR%2Fn0tJhdV@archlinux-ax161/
            echo 'diff --git a/drivers/hv/vmbus_drv.c b/drivers/hv/vmbus_drv.c
index 17bf55fe3169..2376ee484362 100644
--- a/drivers/hv/vmbus_drv.c
+++ b/drivers/hv/vmbus_drv.c
@@ -2079,7 +2079,7 @@ struct hv_device *vmbus_device_create(const guid_t *type,
 	return child_device_obj;
 }
 
-static u64 vmbus_dma_mask = DMA_BIT_MASK(64);
+static u64 vmbus_dma_mask = ~0ULL;
 /*
  * vmbus_device_register - Register the child device
  */' | patch -Np1; or return

        case linux-next-llvm
            # [PATCH] drm/amdgpu: Fix uninitialized variable use warning
            b4 am -o - https://lore.kernel.org/r/20220128064019.2469388-1-lijo.lazar@amd.com/ | patch -Np1; or return

            # https://lore.kernel.org/r/YcC1CobR%2Fn0tJhdV@archlinux-ax161/
            echo 'diff --git a/drivers/hv/vmbus_drv.c b/drivers/hv/vmbus_drv.c
index 17bf55fe3169..2376ee484362 100644
--- a/drivers/hv/vmbus_drv.c
+++ b/drivers/hv/vmbus_drv.c
@@ -2079,7 +2079,7 @@ struct hv_device *vmbus_device_create(const guid_t *type,
 	return child_device_obj;
 }
 
-static u64 vmbus_dma_mask = DMA_BIT_MASK(64);
+static u64 vmbus_dma_mask = ~0ULL;
 /*
  * vmbus_device_register - Register the child device
  */' | patch -Np1; or return
    end

    echo "Setting config..."
    cp $pkgroot/config .config
    podcmd kmake LLVM=1 LLVM_IAS=1 olddefconfig; or return
    diff -u $pkgroot/config .config

    podcmd make -s kernelrelease | string trim >version
    echo "Prepared $pkg version "(cat version)

    podcmd kmake LLVM=1 LLVM_IAS=1 all; or return

    set kernver (cat version)
    set pkgdir $pkgroot/pkg-fish/$pkg
    set modulesdir $pkgdir/usr/lib/modules/$kernver

    # Clean up from prior runs (would normally be done by makepkg)
    rm -rf $pkgdir

    echo "Installing boot image..."
    install -Dm644 (podcmd make -s image_name | string trim) $modulesdir/vmlinuz; or return

    echo "$pkg" | install -Dm644 /dev/stdin $modulesdir/pkgbase

    echo "Installing modules..."
    podcmd kmake INSTALL_MOD_PATH=$pkgdir/usr INSTALL_MOD_STRIP=1 LLVM=1 LLVM_IAS=1 modules_install; or return

    rm $modulesdir/{source,build}; or return

    popd; or return

    command makepkg -R; or return

    set -e fish_trace
    echo Run
    printf '\n\t$ sudo pacman -U %s\n\n' (readlink -f -- *.tar.zst | perl -pe 's/\n/ /')
    echo "to install new kernel"

    popd
end
