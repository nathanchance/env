#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function __print_warning -d "Print a message with a WARNING tag in bold yellow"
    __print_yellow "\nWARNING: $argv\n"
end
