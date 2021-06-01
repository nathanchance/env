#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bllvm -d "Build LLVM using tc-build"
    set i 1
    while test $i -le (count $argv)
        set arg $argv[$i]
        switch $arg
            case --lto
                set -a tc_bld_args --lto thin
            case --pgo
                set -a tc_bld_args --pgo llvm
            case --prefix
                set next (math $i + 1)
                set prefix $argv[$next]
                set i $next
            case --qualify-two-stages
                set prefix (mktemp -d -p $TMP_FOLDER)
                set INSTALL false
            case --qualify
                set -a tc_bld_args --build-stage1-only
                set INSTALL false
        end
        set i (math $i + 1)
    end

    set tc_bld $SRC_FOLDER/tc-build
    header "Updating/cloning tc-build"
    if not test -d $tc_bld
        mkdir -p (dirname $tc_bld)
        git clone https://github.com/ClangBuiltLinux/tc-build $tc_bld
    end
    git -C $tc_bld pull --rebase

    set llvm_src $tc_bld/llvm-project
    if not test -d $llvm_src
        header "Cloning LLVM"
        git clone https://github.com/llvm/llvm-project $llvm_src; or return
    end

    if test -z "$prefix"
        if test -z "$PREFIX"
            set PREFIX $USR_FOLDER
        end
        set stow $PREFIX/stow
        set prefix $stow/packages/llvm/(date +%F-%H-%M-%S)-(git -C $llvm_src sh -s --format=%H origin/main)
    end

    set -a tc_bld_args \
        --check-targets clang lld llvm llvm-unit \
        --clang-vendor (uname -n) \
        --defines CLANG_DEFAULT_LINKER=lld \
        --full-toolchain \
        --install-folder $prefix \
        --no-update \
        --show-build-commands \
        --projects (llvm_all_projects $llvm_src)

    set fish_trace 1
    $tc_bld/build-llvm.py $tc_bld_args; or return

    if test "$INSTALL" != false
        ln -fnrsv $prefix $stow/llvm-latest
        stow -d $stow -R -v llvm-latest
    end
end
