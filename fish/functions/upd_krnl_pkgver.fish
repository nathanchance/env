#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function upd_krnl_pkgver -d "Update the pkgver variable in a kernel PKGBUILD"
    for arg in $argv
        switch $arg
            case '*'
                set krnl $arg
        end
    end

    sed -i 's/pkgver=.*/pkgver='(git -C $CBL_SRC/$krnl describe | string replace -a '-' '.')'/g' $ENV_FOLDER/pkgbuilds/$krnl/PKGBUILD
end
