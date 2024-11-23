#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_bld_llvm_fast -d "Quickly build a version of LLVM from current tree"
    in_tree llvm
    or return 128

    cbl_clone_repo tc-build
    or return

    $CBL_GIT/tc-build/build-llvm.py \
        --assertions \
        --build-folder (tbf) \
        --build-stage1-only \
        --build-targets distribution \
        --llvm-folder . \
        --projects clang lld \
        --quiet-cmake \
        --show-build-commands \
        $argv
end
