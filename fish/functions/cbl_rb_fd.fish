#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_rb_fd -d "Rebase generic Fedora kernel on latest linux-next"
    in_container_msg -c; or return

    set fd_src $CBL_BLD/fedora
    pushd $fd_src; or return

    # Update and patch kernel
    git ru --prune origin; or return
    git rh origin/master

    # Patching
    set -a patches https://lore.kernel.org/all/20221116165810.2876610-1-alexander.deucher@amd.com/ # drm/amd/display: fix the build when DRM_AMD_DC_DCN is not set
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    git am $GITHUB_FOLDER/patches/linux-misc/0001-drm-vc4-Fix-Wuninitialized-in-vc4_hdmi_reset_link.patch; or return

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
