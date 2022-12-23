#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

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

    set -g tmp_dir (mktemp -d -p $TMP_FOLDER)
    for sha in $good_sha $bad_sha
        git checkout $sha; or return

        if test $sha = $bad_sha
            set folder bad
        else
            set folder good
        end

        $CBL_GIT/tc-build/build-llvm.py \
            --assertions \
            --build-folder $tmp_dir/build/llvm-$folder \
            --build-stage1-only \
            --install-folder $tmp_dir/install/llvm-$folder \
            --install-stage1-only \
            --llvm-folder . \
            --projects 'clang;lld' \
            --quiet-cmake; or return
    end

    set cvise $tmp_dir/cvise
    mkdir -p $cvise

    set cvise_test $cvise/test.fish
    echo '#!/usr/bin/env fish

set tmp_dir (dirname (realpath (status dirname)))
set install_folder $tmp_dir/install
set bad_clang $install_folder/llvm-bad/bin/clang
set good_clang $install_folder/llvm-good/bin/clang

function build_kernel
    set type $argv[1]
    set clang_var "$type"_clang

    kmake \
        LLVM=(dirname $$clang_var)/ \
        O=$tmp_dir/build/linux/$type \
end

build_kernel good; or return
build_kernel bad' >$cvise_test
    chmod +x $cvise_test

    git -C $cvise init; or return
    git -C $cvise add test.fish; or return
    git -C $cvise commit -m "Initial commit"; or return

    echo "cvise reduction has been prepared at: $tmp_dir"
end
