#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function __get_llvm_install_path -d "Generate an identifiable install path for LLVM builds"
    set llvm_src $argv[1]
    if not test -e $llvm_src/llvm/CMakeLists.txt
        __print_error "$llvm_src does not appear to be an LLVM tree?"
        return 1
    end
    set llvm_ver (__get_llvm_ver_src $llvm_src)
    or return

    if not set -q date_time
        set date_time (date +%F_%H-%M-%S)
    end

    if not set -q sha
        # 'tail -1' in case a tag is passed for $ref
        set sha (git -C $llvm_src sha $ref | tail -1)
    end

    echo $llvm_ver-$date_time-$sha
end
