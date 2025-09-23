#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_upd_qemu -d "Update QEMU and boot kernels with it"
    cbl_bld_qemu -i -u
    or return

    cbl_lkt \
        --linux-folder $CBL_SRC_P/linux \
        --only-test-boot \
        --targets def
end
