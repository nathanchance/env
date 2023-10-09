#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function eza -d "Calls eza based on how it is available"
    run_cmd (status function) $argv
end
