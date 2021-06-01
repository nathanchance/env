#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function qualify_llvm_uprev -d "Builds LLVM in two different configurations to validate an uprev"
    bllvm --qualify; or return
    bllvm --qualify-two-stages
end
