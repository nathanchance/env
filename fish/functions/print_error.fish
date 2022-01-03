#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function print_error -d "Print a message in bold red"
    printf '\n%bERROR: %s%b\n\n' '\033[01;31m' $argv '\033[0m'
end
