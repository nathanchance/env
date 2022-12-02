#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_rb_fd -d "Rebase generic Fedora kernel on latest linux-next"
    in_container_msg -c; or return

    set fd_src $CBL_BLD/fedora
    pushd $fd_src; or return

    # Update kernel
    git ru --prune origin; or return
    git rh origin/master

    # Patching
    set -a patches https://lore.kernel.org/all/20221130070511.46558-1-vdasa@vmware.com/ # VMCI: Use threaded irqs instead of tasklets
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end
    # https://github.com/ClangBuiltLinux/linux/issues/1767
    git diff 47f68266d6ad94860c6cd9d2145cb91350b47e43^..327b555ed078dde9e119fee497d7ae60b5b1dd62 | git ap -R; or return
    crl https://git.kernel.org/efi/efi/p/71ed3fb090f8b3fb433d946fb8c68053f4a42bd8 | git ap; or return
    crl https://git.kernel.org/efi/efi/p/6736ebb6e18898978f8e49d6ee9662e34993e176 | git ap; or return
    git ac -m "Apply updated version of 'arm64: efi: Move runtime services asm wrapper out of .text'

Link: https://github.com/ClangBuiltLinux/linux/issues/1767"

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
