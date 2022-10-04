#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function get_glibc_version -d "Get glibc version as a five or six digit number"
    set ver_array (ldd --version | head -1 | string match -r '[0-9|.]+' | string split .)
    if test -z "$ver_array[3]"
        set ver_array[3] 0
    end

    printf "%d%02d%02d" $ver_array
end
