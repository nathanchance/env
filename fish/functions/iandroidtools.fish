#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function iandroidtools -d "Install prebuilt tools needed for Android development"
    header "Installing Android tools"

    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set bin $stow/prebuilts/bin

    mkdir -p $bin
    crl -o $bin/repo https://storage.googleapis.com/git-repo-downloads/repo
    chmod a+x $bin/repo

    stow -d $stow -R -v prebuilts
end
