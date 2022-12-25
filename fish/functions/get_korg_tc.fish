#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function get_korg_tc -d "Get kernel.org toolchain path on disk"
    $USER_PYTHON_FOLDER/get_korg_tc.py $argv
end
