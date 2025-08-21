#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_rb_fd -d "Rebase generic Fedora kernel on latest linux-next"
    in_container_msg -c
    or return

    # Prepare kernel source
    PYTHONPATH=$PYTHON_FOLDER/lib python3 -c "import kernel; kernel.prepare_source('fedora')"
    or return

    # Build kernel
    set lnx_src $CBL_SRC_P/fedora
    set lnx_bld (tbf $lnx_src)
    fish -c "cd $lnx_src; and cbl_bld_krnl_rpm --cfi --lto --slim-arm64-platforms arm64"
    or return

    # Copy kernel configuration to easily see changes from Fedora or Linux upstream
    cp -v $lnx_bld/.config $ENV_FOLDER/configs/kernel/fedora-arm64.config
end
