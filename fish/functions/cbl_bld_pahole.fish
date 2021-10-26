#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_bld_pahole -d "Build pahole from source for ClangBuiltLinux"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    header "Building pahole for ClangBuiltLinux"

    set src $SRC_FOLDER/pahole
    if not test -d $src
        mkdir -p (dirname $src)
        git clone https://git.kernel.org/pub/scm/devel/pahole/pahole.git/ $src; or return
    end
    git -C $src clean -dfqx
    git -C $src pull --rebase

    if test -z "$PREFIX"
        set PREFIX $CBL_USR
    end
    set stow $PREFIX/stow
    set prefix $stow/packages/pahole/(date +%F-%H-%M-%S)-(git -C $src show -s --format=%H)

    set bld $src/build

    rm -rf $bld
    cmake \
        -B $bld \
        -D__LIB=lib \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$prefix \
        -S $src; or return
    make -C $bld -skj(nproc) install; or return

    ln -fnrsv $prefix $stow/pahole-latest
    stow -d $stow -R -v pahole-latest

    set -p PATH (dirname $stow)/bin
    command -v pahole
    pahole --version
end
