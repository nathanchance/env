#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function print_error -d "Print a message with an ERROR tag in bold red"
    print_red "\nERROR: $argv\n"
end
