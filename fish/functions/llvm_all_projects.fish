#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function llvm_all_projects -d "Get LLVM_ALL_PROJECTS value minus a couple of problematic projects"
    # llgo is/was broken (https://llvm.org/pr42548)
    # debuginfo-tests breaks frequently due to mlir changes (https://reviews.llvm.org/D98613)
    # debuginfo-tests was renamed to cross-project-tests (https://reviews.llvm.org/D95339)
    grep -F "set(LLVM_ALL_PROJECTS " $argv/llvm/CMakeLists.txt | string split -f 2 '"' | sed -e s/debuginfo-tests// -e s/llgo// -e s/cross-project-tests// -e 's/;;/;/g' -e 's/;$//' -e 's/^;//'
end
