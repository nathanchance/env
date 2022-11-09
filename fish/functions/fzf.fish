#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function fzf -d "Calls fzf based on how it is available"
    run_cmd (status function) $argv
end
