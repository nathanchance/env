#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function iarc -d "Install arcanist"
    header "Installing arcanist"

    set src $SRC_FOLDER/arcanist
    mkdir -p $src
    for repo in arcanist libphutil
        set dir $src/$repo
        if not test -d $dir
            git clone https://github.com/phacility/$repo.git $dir; or return
        end
        git -C $dir pull --rebase --quiet
    end

    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set bin $stow/prebuilts/bin
    mkdir -p $bin
    ln -fsv $src/arcanist/bin/arc $bin/arc
    stow -d $stow -R -v prebuilts
end
