#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function print_yellow -d "Print input in bold, yellow text"
    printf '%b%b%b\n' (set_color -o yellow) "$argv" (set_color normal)
end
