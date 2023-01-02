#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function repo -d "Calls repo based on how it is available"
    run_cmd (status function) $argv
end
