#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function kdiff_headers -d 'Helper function to diff output of linux-headers packages'
    set sed_cmd sed 's;usr/lib/modules/\([0-9|.]\+\)\(-rc[0-9]\+\)\?\(-next-[0-9]\+\)\?\(-[0-9]\+-g[a-f0-9]\+\)\?/;;g'

    if test (count $argv) -ne 2
        __print_error (status function)' <first package> <second_package>'
        return 1
    end

    set pkg1 $argv[1]
    set pkg2 $argv[2]

    for pkg in $pkg1 $pkg2
        if not test -e $pkg
            __print_error "$pkg does not exist!"
            return 1
        end
    end

    git diff --no-index (begin; echo $pkg1; tar -tf $pkg1 | $sed_cmd; end | psub) (begin; echo $pkg2; tar -tf $pkg2 | $sed_cmd; end | psub)
end
