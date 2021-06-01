#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function birg -d "Install ripgrep from GitHub or build it from source"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    set repo BurntSushi/ripgrep
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
        set tar ripgrep-$VERSION-x86_64-unknown-linux-musl.tar.gz

        set work_dir (mktemp -d)
        pushd $work_dir; or return

        header "Installing ripgrep"

        crl $base_url/releases/download/$VERSION/$tar | tar -xzf -; or return

        cd (string replace '.tar.gz' '' $tar); or return
        install -Dm755 rg $bin/rg
        install -Dm644 complete/rg.fish $__fish_config_dir/completions/rg.fish

        stow -d $stow -R -v prebuilts

        set -p PATH (dirname $stow)/bin

        cd
        rm -rf $work_dir
    else
        header "Building ripgrep"
        if not test -d $HOME/.cargo/bin
            irust
        end
        set -p PATH $HOME/.cargo/bin

        set src $SRC_FOLDER/ripgrep/ripgrep-$VERSION

        mkdir -p (dirname $src)
        if not test -d $src
            crl $base_url/archive/$VERSION.tar.gz | tar -C (dirname $src) -xzf -; or return
        end

        pushd $src; or return
        rm -rf target
        cargo build --release --features pcre2; or return
        cargo install --force --path .; or return
        set out (find $src/target -name ripgrep-stamp -print0 | xargs -0 ls -t | head -1 | xargs dirname)
        install -Dm644 $out/rg.fish $__fish_config_dir/completions/rg.fish
    end
    command -v rg
    rg --version
    popd
end
