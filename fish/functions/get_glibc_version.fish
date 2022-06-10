#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function get_glibc_version -d "Get glibc version as a five or six digit number"
    set possible_libc_paths \
        /lib64/libc.so.6 \
        /usr/lib/aarch64-linux-gnu/libc.so.6 \
        /usr/lib/arm-linux-gnueabihf/libc.so.6

    for possible_libc_path in $possible_libc_paths
        if test -f $possible_libc_path
            set libc $possible_libc_path
            break
        end
    end

    set ver_array ($libc --version | head -1 | string match -r '[0-9|.]+' | string split .)
    if test -z "$ver_array[3]"
        set ver_array[3] 0
    end

    printf "%d%02d%02d" $ver_array
end
