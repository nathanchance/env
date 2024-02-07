#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function tbf -d "Prints a build folder specific to the current directory"
    if test (count $argv) -eq 0
        set src $PWD
    else
        set src $argv
    end

    if string match -qr ^$CBL_SRC_W $src
        set base (string split -f 2,3 -m 2 -r / $src | string join -)
    else
        set base (basename $src)
    end

    echo $TMP_BUILD_FOLDER/$base
end
