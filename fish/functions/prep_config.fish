#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function prep_config -d "Prepare kernel configuration in build folder"
    set src_cfg $argv[1]

    set bld $argv[2]
    if test -z "$bld"
        set bld (tbf)
    end
    set dst_cfg $bld/.config

    if string match -qr 'http(s?)://' $src_cfg
        set url true
    else if test -e $src_cfg
        set local true
    else
        __print_error "Could not handle $src_cfg?"
        return 1
    end

    remkdir $bld
    if set -q local
        cp -v $src_cfg $dst_cfg
    end
    if set -q url
        crl -o $dst_cfg $src_cfg
    end
end
