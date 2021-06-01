#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function rbpi -d "Rebase Raspberry Pi kernel on latest linux-next"
    set pi_src $CBL_BLD/rpi

    set fish_trace 1

    pushd $pi_src; or return

    git ru; or return

    git rh origin/master

    set -a patches 20210514213032.575161-1-arnd@kernel.org # [PATCH] drm/msm/dsi: fix 32-bit clang warning
    set -a patches 20210531033426.74031-1-cuibixuan@huawei.com # [PATCH -next v2] mm/mmap_lock: fix warning when CONFIG_TRACING is not defined
    for patch in $patches
        git b4 ams $patch; or return
    end

    for hash in 358afb8b746d4a7ebaeeeaab7a1523895a8572c2 4564363351e2680e55edc23c7953aebd2acb4ab7
        git fp -1 --stdout $hash arch/arm/boot/dts/bcm2711-rpi-4-b.dts | git ap -R; or return
    end
    git ac -m "ARM: dts: bcm2711: Disable the display pipeline"

    for arch in arm arm64
        ../pi-scripts/build.fish $arch; or return
    end

    if not git pll --no-edit mainline master
        rg "<<<<<<< HEAD"; and return
        for arch in arm arm64
            ../pi-scripts/build.fish $arch; or return
        end
        git aa
        git c --no-edit; or return
    end

    for arch in arm arm64
        ../pi-scripts/build.fish $arch; or return
    end

    popd
end
