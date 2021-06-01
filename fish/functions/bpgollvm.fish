#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bpgollvm -d "Build LLVM with Link Time Optimization (LTO) and Profile Guided Optimization (PGO)"
    bllvm --lto --pgo $argv
end
