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
    set -a patches https://lore.kernel.org/all/20230127162906.872395-1-trix@redhat.com/ # udf: remove reporting loc in debug output
    set -a patches https://lore.kernel.org/all/20230127221418.2522612-1-arnd@kernel.org/ # gpu: host1x: fix uninitialized variable use
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    # amdgpu: fix build on non-DCN platforms.
    crl 'https://cgit.freedesktop.org/drm/drm/patch/?id=f439a959dcfb6b39d6fd4b85ca1110a1d1de1587' | git am; or return
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end
    git diff 9d0bccbd7160aa79825b11bf8f4c19cdb9b02b65^..f3db8be4bf6788fa84c997f63143717138ab6b9f | git ap -R; or return
    git ac -m 'kbuild: Revert recent setlocalversion series

Link: https://lore.kernel.org/Y9QmChqp0WEZSk+H@dev-arch.thelio-3990X/'; or return

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
