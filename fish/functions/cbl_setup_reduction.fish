#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_setup_reduction -d "Build good and bad versions of LLVM for cvise reductions"
    if not test -e llvm/CMakeLists.txt
        print_error "Not in an LLVM tree?"
        return 1
    end

    set bad_sha $argv[1]
    if test -z "$bad_sha"
        print_error "No bad sha provided?"
        return 1
    end
    set bad_sha (git sha $bad_sha)
    set good_sha (git sha $bad_sha^)

    set -g tmp_dir (mktemp -d -p $TMP_FOLDER -t cvise.XXXXXXXXXX)
    for sha in $good_sha $bad_sha
        git worktree prune
        git worktree add -d $tmp_dir/src $sha; or return

        if test $sha = $bad_sha
            set folder bad
        else
            set folder good
        end

        if test -d $CBL_TC_BLD
            set tc_bld $CBL_TC_BLD
        else
            set tc_bld $CBL_GIT/tc-build
            cbl_clone_repo (basename $tc_bld)
        end

        $tc_bld/build-llvm.py \
            --assertions \
            --build-folder $tmp_dir/build/llvm-$folder \
            --build-stage1-only \
            --install-folder $tmp_dir/install/llvm-$folder \
            --llvm-folder $tmp_dir/src \
            --projects clang lld \
            --quiet-cmake; or return

        rm -fr $tmp_dir/src
    end

    set cvise $tmp_dir/cvise
    mkdir -p $cvise

    set cvise_test $cvise/test.fish
    echo '#!/usr/bin/env fish

set tmp_dir (dirname (realpath (status dirname)))
set install_folder $tmp_dir/install
set bad_clang $install_folder/llvm-bad/bin/clang
set good_clang $install_folder/llvm-good/bin/clang

set lnx_src
set make_args

if test -z "$lnx_src"
    echo "No Linux source folder set?"
    return 1
end
if not test -d $lnx_src
    echo "Linux source does not exist?"
    return 1
end
if test -z "$make_args"
    echo "No make target set?"
    return 1
end

function build_kernel
    set type $argv[1]
    set clang_var "$type"_clang

    kmake \
        -C $lnx_src \
        LLVM=(dirname $$clang_var)/ \
        O=$tmp_dir/build/linux/$type \
        mrproper $make_args
end

build_kernel good; or return
build_kernel bad' >$cvise_test
    chmod +x $cvise_test

    git -C $cvise init; or return
    git -C $cvise add test.fish; or return
    git -C $cvise commit -m "Initial commit"; or return

    echo "cvise reduction has been prepared at: $tmp_dir"
end
