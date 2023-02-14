#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_upd_qemu -d "Update QEMU and boot kernels with it"
    cbl_bld_qemu -u; or return
    cbl_lkt \
        --boot-testing-only \
        --linux-folder $CBL_BLD_P/linux \
        --targets def
end
