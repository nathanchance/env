#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function get_glibc_version -d "Get glibc version as a five or six digit number"
    PYTHONPATH=$PYTHON_LIB_FOLDER python3 -c 'import root
glibc_version = root.get_glibc_version()
print(f"{glibc_version[0]:d}{glibc_version[1]:02d}{glibc_version[2]:02d}")'
end
