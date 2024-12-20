#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function esc_home -d "Replace $HOME with ~"
    string replace $HOME \~ $argv
end
