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
    # https://lore.kernel.org/20240130170556.GA1125757@dev-arch.thelio-3990X/
    set -a reverts 196f34af2bf4c87ac4299a9775503d81b446980c # tty: serial: amba-pl011: Remove QDF2xxx workarounds
    for revert in $reverts
        git revert --mainline 1 --no-edit $revert; or return
    end
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    set -a crl_patches https://git.kernel.org/masahiroy/linux-kbuild/p/736aa206be27a86db657a383f1505737e03b5891 # rpm-pkg: simplify installkernel %post
    set -a crl_patches https://git.kernel.org/tj/wq/p/15930da42f8981dc42c19038042947b475b19f47 # workqueue: Don't call cpumask_test_cpu() with -1 CPU in wq_update_node_max_active()
    for patch in $crl_patches
        crl $patch | git am -3; or return
    end
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end
    # https://lore.kernel.org/all/CAK7LNAQCiBtQ3kQznPDKtkD83wpCzodPVDs8eFnfnx5=Y8E5Cw@mail.gmail.com/2-0001-kbuild-rpm-pkg-specify-more-files-as-ghost.patch
    set -a am_patches $NVME_FOLDER/data/tmp-patches/0001-kbuild-rpm-pkg-specify-more-files-as-ghost.patch # kbuild: rpm-pkg: specify more files as %ghost
    for patch in $am_patches
        git am -3 $patch; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
