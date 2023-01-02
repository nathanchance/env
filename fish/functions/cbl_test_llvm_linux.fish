#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_test_llvm_linux -d "Test stable and mainline Linux with all supported versions of LLVM"
    cbl_test_llvm_mainline_linux
    cbl_test_llvm_stable_linux
end
