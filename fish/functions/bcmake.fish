#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bcmake -d "Build cmake from source"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    header "Building cmake"

    set repo Kitware/CMake
    if test -z "$VERSION"
        set VERSION (glr $repo)
    end
    set VERSION (string replace 'v' '' $VERSION)
    set src $SRC_FOLDER/cmake/cmake-$VERSION
    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set prefix $stow/packages/cmake/(date +%F-%H-%M-%S)-$VERSION

    if not test -d $src
        mkdir -p (dirname $src)
        crl https://github.com/$repo/releases/download/v$VERSION/(basename $src).tar.gz | tar -C (dirname $src) -xzf -; or return
    end

    set bld $src/build
    rm -rf $bld
    mkdir -p $bld

    pushd $bld; or return
    $src/bootstrap --parallel=(nproc) --prefix=$prefix; or return
    time make -j(nproc) install; or return

    ln -fnrsv $prefix $stow/cmake-latest
    stow -d $stow -R -v cmake-latest

    set -p PATH (dirname $stow)/bin
    command -v cmake
    cmake --version

    popd
end
