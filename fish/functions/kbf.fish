#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function kbf -d "Prints a build folder specific to the current directory for use with O="
    if test (count $argv) -eq 0
        set src $PWD
    else
        set src $argv
    end

    if string match -qr ^$CBL_WRKTR $src
        set base (string join - (string split -f 2,3 -m 2 -r / $src))
    else
        set base (basename $src)
    end

    echo $TMP_BUILD_FOLDER/$base
end
