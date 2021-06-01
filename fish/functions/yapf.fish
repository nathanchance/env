#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function yapf -d "Download yapf if necessary then run it"
    set src $SRC_FOLDER/yapf
    if not test -d $src
        mkdir -p (dirname $src)
        git clone https://github.com/google/yapf $src
    end

    PYTHONPATH=$src python3 $src/yapf -i -p $argv
end
