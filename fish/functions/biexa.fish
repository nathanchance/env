#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function biexa -d "Install exa from GitHub or build it from source"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    set repo ogham/exa
    set base_url https://github.com/$repo
    if test -z "$VERSION"
        set VERSION (glr $repo)
    end

    if test (uname -m) = x86_64
        if test -z "$PREFIX"
            set PREFIX $USR_FOLDER
        end
        set stow $PREFIX/stow
        set bin $stow/prebuilts/bin
        set zip exa-linux-x86_64-$VERSION.zip

        set work_dir (mktemp -d)
        pushd $work_dir; or return

        header "Installing exa"

        crl -O $base_url/releases/download/$VERSION/$zip; or return
        unzip $zip; or return
        install -Dm755 bin/exa $bin/exa
        install -Dm644 completions/exa.fish $__fish_config_dir/completions/exa.fish
        stow -d $stow -R -v prebuilts
        set -p PATH (dirname $stow)/bin
        cd
        rm -rf $work_dir
    else
        header "Building exa"
        if not test -d $HOME/.cargo/bin
            irust
        end
        set -p PATH $HOME/.cargo/bin

        set src $SRC_FOLDER/exa/exa-(string replace 'v' '' $VERSION)

        if not test -d $src
            mkdir -p (dirname $src)
            crl $base_url/archive/$VERSION.tar.gz | tar -C (dirname $src) -xzf -; or return
        end

        pushd $src; or return
        cargo build --release; or return
        cargo install --force --path .; or return
    end
    command -v exa
    exa --version
    popd
end
