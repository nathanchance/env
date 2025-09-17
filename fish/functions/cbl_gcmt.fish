#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function cbl_gcmt -d "Run git commit with preset commit message"
    for arg in $argv
        switch $arg
            case '*'
                __print_error "Unhandled argument: $arg"
                return 1
        end
    end
end
