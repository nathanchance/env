#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function gen_lnx_pkgver -d "Wrapper for gen_lnx_pkgver.py"
    $PYTHON_SCRIPTS_FOLDER/gen_lnx_pkgver.py $argv
end
