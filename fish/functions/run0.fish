#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function run0 -d "Wrapper around 'doas' or 'sudo'"
    if command -q doas
        command doas $argv
    else if command -q sudo
        command sudo $argv
    else
        __print_error "No suitable root access binary found?"
        return 1
    end
end
