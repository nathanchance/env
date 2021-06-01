#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bninja -d "Build ninja from source"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    header "Building ninja"

    set repo ninja-build/ninja
    if test -z "$VERSION"
        set VERSION (glr $repo)
    end
    set VERSION (string replace 'v' '' $VERSION)
    set src $SRC_FOLDER/ninja/ninja-$VERSION
    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set prefix $stow/packages/ninja/(date +%F-%H-%M-%S)-$VERSION

    if not test -d $src
        mkdir -p (dirname $src)
        crl https://github.com/$repo/archive/v$VERSION.tar.gz | tar -C (dirname $src) -xzf -; or return
    end

    pushd $src; or return
    python3 ./configure.py --bootstrap; or return
    install -Dm755 ninja $prefix/bin/ninja

    ln -fnrsv $prefix $stow/ninja-latest
    stow -d $stow -R -v ninja-latest

    set -p PATH (dirname $stow)/bin

    command -v ninja
    ninja --version

    popd
end
