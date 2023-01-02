#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function print_green -d "Print input in bold, green text"
    printf '%b%b%b\n' (set_color -o green) "$argv" (set_color normal)
end
