#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bccache -d "Build ccache from source"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    header "Building ccache"

    set repo ccache/ccache
    if test -z "$VERSION"
        set VERSION (glr $repo)
    end
    set VERSION (string replace 'v' '' $VERSION)
    set src $SRC_FOLDER/ccache/ccache-$VERSION
    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set prefix $stow/packages/ccache/(date +%F-%H-%M-%S)-$VERSION

    if not test -d "$src"
        mkdir -p (dirname $src)
        crl https://github.com/$repo/releases/download/v$VERSION/(basename $src).tar.gz | tar -C (dirname $src) -xzf -; or return
    end

    set bld $src/build
    rm -rf $bld
    mkdir -p $bld

    set -a cmake_args -B $bld
    set -a cmake_args -DCMAKE_BUILD_TYPE=Release
    set -a cmake_args -DCMAKE_INSTALL_PREFIX=$prefix
    set -a cmake_args -DZSTD_FROM_INTERNET=ON

    cmake $cmake_args $src; or return
    time make -C $bld -j(nproc) install; or return
    ln -fnrsv $prefix $stow/ccache-latest
    stow -d $stow -R -v ccache-latest
    set -p PATH (dirname $stow)/bin
    command -v ccache
    ccache --version
end
