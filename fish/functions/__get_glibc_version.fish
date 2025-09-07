#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function __get_glibc_version -d "Get glibc version as a five or six digit number"
    PYTHONPATH=$PYTHON_LIB_FOLDER python3 -c 'import setup
glibc_version = setup.get_glibc_version()
print(f"{glibc_version[0]:d}{glibc_version[1]:02d}{glibc_version[2]:02d}")'
end
