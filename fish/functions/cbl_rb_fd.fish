#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_rb_fd -d "Rebase generic Fedora kernel on latest linux-next"
    in_container_msg -c; or return

    set fd_src $CBL_BLD/fedora
    pushd $fd_src; or return

    # Update kernel
    git ru --prune origin; or return
    git rh origin/master

    # Patching
    for revert in $reverts
        git revert --no-edit $revert; or return
    end
    set -a b4_patches https://lore.kernel.org/all/20230519124438.365184-1-srinivasan.shanmugam@amd.com/ # drm/amdgpu: Mark mmhub_v1_8_mmea_err_status_reg as __maybe_unused
    set -a b4_patches https://lore.kernel.org/all/20230525212723.3361524-2-oliver.upton@linux.dev/ # KVM: arm64: Iterate arm_pmus list to probe for default PMU
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for patch in $crl_patches
        crl $patch | git am -3; or return
    end
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
