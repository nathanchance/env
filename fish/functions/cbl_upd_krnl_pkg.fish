#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_upd_krnl_pkg -d "Update Arch Linux ClangBuiltLinux kernels"
    for arg in $argv
        set krnl linux-(string replace 'linux-' '' $arg)
        switch $krnl
            case linux-cfi
                pushd $CBL_SRC/$krnl; or return
                git ru; or return
                git rb -i origin/master; or return
                popd

            case linux-debug linux-mainline'*' linux-next'*'
                set pkgbuild $ENV_FOLDER/pkgbuilds/$krnl/PKGBUILD
                if not test -f $pkgbuild
                    print_error "$pkgbuild does not exist!"
                    return 1
                end
                vim $pkgbuild; or return
        end

        cbl_bld_krnl_pkg $krnl
    end
end
