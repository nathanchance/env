#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bmake -d "Build make from source"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    header "Building make"

    if test -z "$VERSION"
        set VERSION 4.3
    end
    set src $SRC_FOLDER/make/make-$VERSION
    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set prefix $stow/packages/make/(date +%F-%H-%M-%S)-$VERSION

    if not test -d "$src"
        mkdir -p (dirname $src)
        crl http://ftp.gnu.org/gnu/make/(basename $src).tar.gz | tar -C (dirname $src) -xzf -; or return
    end

    set bld $src/build
    rm -rf $bld
    mkdir -p $bld
    pushd $bld; or return

    $src/configure --prefix=$prefix; or return
    time make -j(nproc) install; or return

    ln -fnrsv $prefix $stow/make-latest
    stow -d $stow -R -v make-latest
    set -p PATH (dirname $stow)/bin

    command -v make
    make --version

    popd
end
