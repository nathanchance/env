#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function get_latest_stable_llvm_version -d 'Get the latest stable version for an LLVM major version'
    for arg in $argv
        switch $arg
            case 17
                echo $arg.0.0-rc3
            case 15
                echo $arg.0.7
            case 14 16
                echo $arg.0.6
            case 12 13
                echo $arg.0.1
            case 11
                echo $arg.1.0
        end
    end
end
