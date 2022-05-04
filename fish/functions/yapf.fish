#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function yapf -d "Run yapf from a git checkout"
    if command -q yapf
        command yapf -i -p $argv
    else
        set yapf $BIN_SRC_FOLDER/yapf/yapf
        if not test -d $yapf
            upd yapf; or return
        end
        PYTHONPATH=(dirname $yapf) python3 $yapf -i -p $argv
    end
end
