#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function b4 -d "Calls b4 based on how it is available"
    run_cmd (status function) $argv
end
