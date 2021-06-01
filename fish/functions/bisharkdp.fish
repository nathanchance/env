#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bisharkdp -d "Install sharkdp binaries from GitHub or build them from source"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    for arg in $argv
        switch $arg
            case all
                set binaries bat diskus fd hyperfine
            case bat diskus fd hyperfine
                set -a binaries $arg
        end
    end

    set work (mktemp -d)
    pushd $work; or return

    for binary in $binaries
        set repo sharkdp/$binary
        set base_url https://github.com/$repo
        if test -z "$VERSION"
            set _version (glr $repo)
        else
            set _version $VERSION
        end

        if test (uname -m) = x86_64
            if test -z "$PREFIX"
                set PREFIX $USR_FOLDER
            end
            set stow $PREFIX/stow
            set bin $stow/prebuilts/bin
            set tar $binary-$_version-x86_64-unknown-linux-gnu.tar.gz

            header "Installing $binary"

            crl $base_url/releases/download/$_version/$tar | tar -xzf -; or return
            pushd (string replace '.tar.gz' '' $tar); or return
            install -Dm755 $binary $bin/$binary
            switch $binary
                case bat fd hyperfine
                    install -Dvm644 autocomplete/$binary.fish $__fish_config_dir/completions/$binary.fish
            end
            stow -d $stow -R -v prebuilts
            set -p PATH (dirname $stow)/bin
            popd
        else
            header "Building $binary"
            if not test -d $HOME/.cargo/bin
                irust
            end
            set -p PATH $HOME/.cargo/bin

            set src $SRC_FOLDER/$binary/$binary-(string replace 'v' '' $_version)
            if not test -d $src
                mkdir -p (dirname $src)
                crl $base_url/archive/$_version.tar.gz | tar -C (dirname $src) -xzf -; or return
            end

            pushd $src; or return
            rm -rf target
            cargo build --release; or return
            cargo install --force --path .; or return
            switch $binary
                case bat fd hyperfine
                    set comp (find target -name "$binary.fish" | head -1)
                    if test -f $comp
                        install -Dvm644 $comp $__fish_config_dir/completions/$binary.fish
                    end
            end
            popd
        end
        command -v $binary
        eval $binary --version
    end
    popd
end
