#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function print_warning -d "Print a message in bold yellow"
    printf '\n%bWARNING: %s%b\n\n' '\033[01;33m' $argv '\033[0m'
end
