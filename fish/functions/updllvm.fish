#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function updllvm -d "Updates LLVM for system-wide use"
    set tc_bld $SRC_FOLDER/tc-build
    if not test -d $tc_bld
        mkdir -p (dirname $tc_bld)
        git clone https://github.com/ClangBuiltLinux/tc-build $tc_bld; or return
    end
    git -C $tc_bld pull -q -r; or return

    set llvm_src $tc_bld/llvm-project
    if not test -d $llvm_src
        git clone https://github.com/llvm/llvm-project $llvm_src
    end
    git -C $llvm_src pull -q -r; or return

    qualify_llvm_uprev; or return
    switch $LOCATION
        case server
            bpgollvm
        case '*'
            bllvm
    end
end
