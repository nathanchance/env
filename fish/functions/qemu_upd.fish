#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function qemu_upd -d "Update QEMU and boot kernels with it"
    qemu_build -u
    lt --defconfigs --linux-src $CBL_BLD_P/linux
end
