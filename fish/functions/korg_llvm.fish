#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function korg_llvm -d "Print LLVM variable for use with Kbuild"
    echo LLVM=$CBL_TC_LLVM_STORE/(get_latest_stable_llvm_version $argv)/bin/
end
