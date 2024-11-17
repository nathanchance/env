#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function in_tree -d "Checks if we are in a particular source tree"
    set type $argv[1]
    if test -z "$type"
        print_error "No type provided?"
        return 128
    end

    switch $type
        case kernel
            set file Makefile
            set msg "a $type"
        case llvm
            set file llvm/CMakeLists.txt
            set msg "an "(string upper $type)
    end

    if not test -f $file
        print_error "You do not appear to be in $msg tree!"
        return 1
    end
end
