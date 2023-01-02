#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function print_red -d "Print input in bold, red text"
    printf '%b%b%b\n' (set_color -o red) "$argv" (set_color normal)
end
