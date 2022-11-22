#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function print_warning -d "Print a message with a WARNING tag in bold yellow"
    print_yellow "\nWARNING: $argv\n"
end
