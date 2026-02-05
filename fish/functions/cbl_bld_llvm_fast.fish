#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_bld_llvm_fast -d "Quickly build a version of LLVM" -w build-llvm.py
    for arg in $argv
        switch $arg
            case --no-multicall
                set no_multicall true
            case '*'
                set -a bld_llvm_args $arg
        end
    end
    if contains -- -l $bld_llvm_args
        set llvm_flag -l
    end
    if contains -- --llvm-folder $bld_llvm_args
        set llvm_flag --llvm-folder
    end
    if set -q llvm_flag
        set llvm_folder $bld_llvm_args[(math (contains -i -- $llvm_flag $bld_llvm_args) + 1)]
        set bld_folder (tbf $llvm_folder)
    end
    if not set -q llvm_folder
        __in_tree llvm
        or return 128

        set llvm_folder .
        set bld_folder (tbf)
    end

    if not set -q tc_bld
        cbl_clone_repo tc-build
        or return

        set tc_bld $CBL_GIT/tc-build
    end

    if not contains -- --pgo $bld_llvm_args
        set -a bld_llvm_args --build-stage1-only
    end
    if not set -q no_multicall
        set -a bld_llvm_args --multicall
    end

    $tc_bld/build-llvm.py \
        --assertions \
        --build-folder $bld_folder \
        --build-targets distribution \
        --llvm-folder $llvm_folder \
        --projects clang lld \
        --quiet-cmake \
        --show-build-commands \
        $bld_llvm_args
end
