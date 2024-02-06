#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_upd_krnl_pkgver -d "Update the pkgver variable in a kernel PKGBUILD"
    for arg in $argv
        switch $arg
            case -b --bisect
                set bisect true
            case '*'
                set krnl linux-(string replace 'linux-' '' $arg)
        end
    end

    set pkgbuild $ENV_FOLDER/pkgbuilds/$krnl

    if test "$bisect" = true
        set src $pkgbuild/src/$krnl
    else
        set src $CBL_SRC_D/$krnl
    end

    sed -i 's/pkgver=.*/pkgver='(git -C $src describe | string replace -a '-' '.')'/g' $pkgbuild/PKGBUILD
end
