#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bdtc -d "Build dtc from source"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    header "Building dtc"

    set src $SRC_FOLDER/dtc
    if not test -d $src
        mkdir -p (dirname $src)
        git clone https://git.kernel.org/pub/scm/utils/dtc/dtc.git $src; or return
    end
    git -C $src clean -fxdq
    git -C $src fetch
    if test -z "$VERSION"
        set VERSION (git -C $src describe --tags (git -C $src rev-list --tags --max-count=1))
    end
    set VERSION (string replace 'v' '' $VERSION)
    git -C $src checkout v$VERSION

    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set prefix $stow/packages/dtc/(date +%F-%H-%M-%S)-$VERSION

    time make -C $src -j(nproc) NO_PYTHON=1 PREFIX=$prefix install; or return

    ln -fnrsv $prefix $stow/dtc-latest
    stow -d $stow -R -v dtc-latest

    set -p PATH (dirname $stow)/bin
    command -v dtc
    dtc --version
end
