#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_upd_qemu -d "Update QEMU and boot kernels with it"
    cbl_bld_qemu -u
    cbl_lkt --defconfigs --linux-src $CBL_BLD_P/linux
end
