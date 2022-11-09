#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function shfmt -d "Calls shfmt based on how it is available"
    run_cmd (status function) $argv
end
