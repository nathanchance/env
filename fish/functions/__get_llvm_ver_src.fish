#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function __get_llvm_ver_src -d "Get LLVM version from source code"
    set llvm_src $argv[1]
    if not test -e $llvm_src/llvm/CMakeLists.txt
        __print_error "$llvm_src does not appear to be an LLVM tree?"
        return 1
    end
    set llvm_ver_cmake $llvm_src/cmake/Modules/LLVMVersion.cmake
    # https://github.com/llvm/llvm-project/commit/81e20472a0c5a4a8edc5ec38dc345d580681af81
    if not test -e $llvm_ver_cmake
        set llvm_ver_cmake $llvm_src/llvm/CMakeLists.txt
    end
    if not set llvm_ver (string match -gr "\s+set\(LLVM_VERSION_[A-Z]+ ([0-9]+)\)" <$llvm_ver_cmake)
        __print_error "Could not find LLVM version in $llvm_ver_cmake"
        return 1
    end

    string join . $llvm_ver
end
