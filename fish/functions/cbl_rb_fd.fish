#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_rb_fd -d "Rebase generic Fedora kernel on latest linux-next"
    in_container_msg -c
    or return

    # Prepare kernel source
    PYTHONPATH=$PYTHON_FOLDER/lib python3 -c "import kernel; kernel.prepare_source('fedora')"

    # Build kernel
    fish -c "cd $CBL_SRC_P/fedora; and cbl_bld_krnl_rpm --cfi --lto arm64"
end
