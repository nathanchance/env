#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_upd_krnl_pkg -d "Update Arch Linux ClangBuiltLinux kernels"
    for arg in $argv
        set krnl linux-(string replace 'linux-' '' $arg)
        set pkgbuild $ENV_FOLDER/pkgbuilds/$krnl/PKGBUILD
        if not test -f $pkgbuild
            print_error "$pkgbuild does not exist!"
            return 1
        end
        vim $pkgbuild; or return

        cbl_bld_krnl_pkg --cfi --lto $krnl
    end
end
