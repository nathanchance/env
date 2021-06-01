#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function ishfmt -d "Install shfmt"
    header "Installing shfmt"

    set repo mvdan/sh
    if test -z "$VERSION"
        set VERSION (glr $repo)
    end
    set VERSION v(string replace 'v' '' $VERSION)

    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set bin $stow/prebuilts/bin/shfmt

    mkdir -p (dirname $bin)
    rm -rf $bin
    crl -o $bin https://github.com/$repo/releases/download/$VERSION/shfmt_"$VERSION"_linux_amd64; or return
    chmod +x $bin
    stow -d $stow -R -v prebuilts
end
