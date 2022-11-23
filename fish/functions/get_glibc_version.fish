#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function get_glibc_version -d "Get glibc version as a five or six digit number"
    $PYTHON_FOLDER/get_glibc_version.py
end
