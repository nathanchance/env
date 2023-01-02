#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function header -d "Prints a formatter header to signal what is being done to the user"
    set border "===="(for i in (seq 1 (string length $argv)); printf "="; end)"===="
    printf '\n\033[01;34m%s\n%s\n%s\033[0m\n\n' $border "==  $argv  ==" $border
end
