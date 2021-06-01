#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bcvise -d "Build cvise from source"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    for llvm_ver in (seq 20 -1 7)
        set llvm_dir /usr/lib/llvm-$llvm_ver
        if test -d $llvm_dir
            set cmake_prefix_path $llvm_dir
            break
        end
    end
    if test -z "$cmake_prefix_path"
        set cmake_prefix_path /usr
    end

    set clang_ver ($ENV_FOLDER/external/cc-version.sh $cmake_prefix_path/bin/clang)
    if test $clang_ver -lt 90000; or test $clang_ver -ge 130000
        header "Skipping cvise due to incompatible clang"
        return 0
    end

    header "Building cvise"

    set repo marxin/cvise
    if test -z "$VERSION"
        set VERSION (glr $repo)
    end
    set VERSION (string replace 'v' '' $VERSION)
    set src $SRC_FOLDER/cvise/cvise-$VERSION
    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set prefix $stow/packages/cvise/(date +%F-%H-%M-%S)-$VERSION

    if not test -d $src
        mkdir -p (dirname $src)
        crl https://github.com/$repo/archive/v$VERSION.tar.gz | tar -C (dirname $src) -xzf -
    end
    python3 -m pip install --upgrade --user pebble pytest
    fish_add_path $HOME/.local/bin

    set bld $src/build
    rm -rf $bld
    mkdir -p $bld

    set cmake_args \
        -B $bld \
        -DCMAKE_C_COMPILER=(command -v clang; or command -v gcc) \
        -DCMAKE_CXX_COMPILER=(command -v clang++; or command -v g++) \
        -DCMAKE_INSTALL_PREFIX=$prefix \
        -DCMAKE_PREFIX_PATH=$cmake_prefix_path \
        -DPYTHON_EXECUTABLE=(command -v python3)

    cmake $cmake_args $src; or return
    time make -C $bld -j(nproc) install; or return

    ln -fnrsv $prefix $stow/cvise-latest
    stow -d $stow -R -v cvise-latest

    set -p PATH (dirname $stow)/bin
    command -v cvise
    cvise --version
end
