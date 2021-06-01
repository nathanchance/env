#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function duf -d "Run duf with ASCII style by default" -w duf
    command duf -style ascii $argv
end
