#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function test_llvm_linux -d "Test stable and mainline Linux with all supported versions of LLVM"
    test_llvm_mainline_linux
    test_llvm_stable_linux
end
