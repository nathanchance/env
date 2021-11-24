#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function ls -d "Use exa instead of ls if it is available" -w exa
    exa $argv
end
