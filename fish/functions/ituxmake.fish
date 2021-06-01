#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function ituxmake -d "Install tuxmake"
    set src $SRC_FOLDER/tuxmake
    if not test -d $src
        mkdir -p (dirname $src)
        git clone https://gitlab.com/Linaro/tuxmake.git $src; or return
    end
    git -C $src pull --rebase

    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set bin $stow/prebuilts/bin

    mkdir -p $bin
    ln -fsv $src/run $bin/tuxmake
    stow -d $stow -R -v prebuilts
end
