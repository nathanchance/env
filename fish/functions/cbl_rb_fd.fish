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
    set -a patches https://lore.kernel.org/all/20221130070511.46558-1-vdasa@vmware.com/ # VMCI: Use threaded irqs instead of tasklets
    set -a patches https://lore.kernel.org/all/20230108224057.354438-2-beanhuo@iokpp.de/ # scsi: ufs: core: bsg: Fix sometimes-uninitialized warnings
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end
    # https://lore.kernel.org/Y73PAtm6FPuT+1cM@dev-arch.thelio-3990X/
    git fp -2 --stdout a7334dc70496bb0ce | git ap -R; or return
    git f https://git.kernel.org/pub/scm/linux/kernel/git/efi/efi.git/ urgent; or return
    git fp -2 --stdout b9c66533400fad0f31aed561bae92638986b6b28 | git ap; or return
    git ac -m "Apply updated version of 'efi: Follow-up fixes for EFI runtime stack'"

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
