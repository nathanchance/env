#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_bld_llvm_sbs -d "Build identical copies of LLVM side by side from various revisions"
    in_tree llvm
    or return 128

    set prefix $argv[1]

    for arg in $argv[2..]
        # either short or full SHA
        if string match -qr '[0-9a-f]{12}' $arg; or string match -qr '[0-9a-f]{40}' $arg
            set -a shas $arg
        else
            set -a bld_llvm_args $arg
        end
    end

    for sha in $shas
        git worktree prune
        git worktree add -d $prefix/src $sha
        or return

        if test -d $CBL_TC_BLD
            set tc_bld $CBL_TC_BLD
        else
            set tc_bld $CBL_GIT/tc-build
            cbl_clone_repo (basename $tc_bld)
        end

        $tc_bld/build-llvm.py \
            --assertions \
            --build-folder $tmp_dir/build/llvm-$sha \
            --build-stage1-only \
            --install-folder $tmp_dir/install/llvm-$sha \
            --llvm-folder $tmp_dir/src \
            --projects clang lld \
            --quiet-cmake \
            $bld_llvm_args
        or return

        rm -fr $tmp_dir/src
    end
end
