#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function fdshfmt -d "Find and format all shell scripts ending with .{ba,}sh in a directory"
    switch (basename $PWD)
        case env
            fd -t x -E fish -E windows -x shfmt -ci -i 4 -w
        case '*'
            fd -e bash -e sh -x shfmt -ci -i 4 -w
    end
end
