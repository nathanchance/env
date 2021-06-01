#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function ib4 -d "Download and install b4"
    header "Installing b4"

    set src $SRC_FOLDER/b4
    if not test -d "$src"
        mkdir -p (dirname $src)
        git clone https://git.kernel.org/pub/scm/utils/b4/b4.git/ $src; or return
    end
    git -C $src pull --rebase

    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set bin $stow/prebuilts/bin
    mkdir -p $bin
    ln -fsv $src/b4.sh $bin/b4
    python3 -m pip install --requirement $src/requirements.txt --upgrade --user
    stow -d $stow -R -v prebuilts
end
