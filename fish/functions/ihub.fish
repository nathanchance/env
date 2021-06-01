#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function ihub -d "Install hub"
    header "Installing hub"

    set repo github/hub
    if test -z "$HUB_VERSION"
        set HUB_VERSION (glr $repo)
    end

    switch (uname -m)
        case armv7l
            set arch arm
        case aarch64
            if command -q dpkg
                switch (dpkg --print-architecture)
                    case armhf
                        set arch arm
                    case '*'
                        set arch arm64
                end
            else
                set arch arm64
            end
        case x86_64
            set arch amd64
        case '*'
            return
    end

    pushd (mktemp -d); or return

    set hub_tuple hub-linux-$arch-(string replace 'v' '' $HUB_VERSION)
    crl -O https://github.com/$repo/releases/download/$HUB_VERSION/$hub_tuple.tgz; or return
    tar -xf $hub_tuple.tgz; or return

    if test -z "$PREFIX"
        set -x PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    PREFIX=$stow/prebuilts ./$hub_tuple/install; or return

    stow -d $stow -R -v prebuilts

    install -Dm644 $hub_tuple/etc/hub.fish_completion $__fish_config_dir/completions/hub.fish

    rm -rf $PWD

    popd
end
