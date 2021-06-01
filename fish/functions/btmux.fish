#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function btmux -d "Build tmux from source"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    header "Building tmux"

    set repo tmux/tmux
    if test -z "$VERSION"
        set VERSION (glr $repo)
    end
    set src $SRC_FOLDER/tmux/tmux-$VERSION
    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set prefix $stow/packages/tmux/(date +%F-%H-%M-%S)-$VERSION

    if not test -d "$src"
        mkdir -p (dirname $src)
        crl https://github.com/$repo/releases/download/$VERSION/(basename $src).tar.gz | tar -C (dirname $src) -xzf -; or return
    end

    set bld $src/build
    rm -rf $bld
    mkdir -p $bld
    pushd $bld; or return

    $src/configure --prefix=$prefix; or return
    time make -j(nproc) install; or return

    ln -fnrsv $prefix $stow/tmux-latest
    stow -d $stow -R -v tmux-latest

    set -p PATH (dirname $stow)/bin

    command -v tmux
    tmux -V

    popd
end
