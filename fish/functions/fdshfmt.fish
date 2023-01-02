#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function fdshfmt -d "Find and format all shell scripts ending with .{ba,}sh in a directory"
    switch (basename $PWD)
        case env
            fd -t x -E{ bin,fish,python,windows} -X fish -c 'shfmt -ci -i 4 -w $argv'
    end
    fd -e{ ba,}sh -X fish -c 'shfmt -ci -i 4 -w $argv'
end
