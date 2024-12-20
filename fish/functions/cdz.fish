#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cdz -d "Use z for changing directory if running interactively, cd otherwise"
    if type -q z
        z $argv
    else
        cd $argv
    end
end
