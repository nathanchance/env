#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function fdshfmt -d "Find and format all shell scripts ending with .{ba,}sh in a directory"
    switch (basename $PWD)
        case env
            fd -t x -E{ bin,fish,windows} -X fish -c 'shfmt -ci -i 4 -w $argv'
        case '*'
            fd -e bash -e sh -X fish -c 'shfmt -ci -i 4 -w $argv'
    end
end
