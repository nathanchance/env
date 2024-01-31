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
    # https://lore.kernel.org/20240130180010.GA2011608@dev-arch.thelio-3990X/
    set -a reverts 5797b1c18919cd9c289ded7954383e499f729ce0 # workqueue: Implement system-wide nr_active enforcement for unbound workqueues
    # https://lore.kernel.org/20240130170556.GA1125757@dev-arch.thelio-3990X/
    set -a reverts 196f34af2bf4c87ac4299a9775503d81b446980c # tty: serial: amba-pl011: Remove QDF2xxx workarounds
    # https://lore.kernel.org/20240130091626.GA3684878@google.com/
    set -a reverts 65929884f868cd5ed4e715e55ca66183b538c11a # modules: Remove #ifdef CONFIG_STRICT_MODULE_RWX around rodata_enabled
    set -a reverts 677bfb9db8a37a8e61d3e8f97bbfd43e89b98e92 # module: Don't ignore errors from set_memory_XX()
    for revert in $reverts
        git revert --mainline 1 --no-edit $revert; or return
    end
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    set -a crl_patches https://git.kernel.org/masahiroy/linux-kbuild/p/736aa206be27a86db657a383f1505737e03b5891 # rpm-pkg: simplify installkernel %post
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
