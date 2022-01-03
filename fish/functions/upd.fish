#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function upd -d "Runs the update command for the current distro or downloads/updates requested binary"
    if test (count $argv) -eq 0
        set targets os
    else
        set targets $argv
    end

    for target in $targets
        if test "$target" = os
            switch (get_distro)
                case arch
                    sudo pacman -Syyu
                case debian ubuntu
                    sudo sh -c 'apt update && apt upgrade && apt autoremove -y'
            end
            continue
        end
        # These need to be local to the loop so they are reset each invocation
        set -l git_clone_args
        set -l git_urls
        set -l subfolder
        set -l submodules

        switch $target
            case arc
                set git_urls https://github.com/phacility/arcanist https://github.com/phacility/libphutil
                set subfolder arcanist
            case b4
                set git_clone_args --recursive
                set git_urls https://git.kernel.org/pub/scm/utils/b4/b4.git
                set submodules true
            case tuxmake
                set git_urls https://gitlab.com/Linaro/tuxmake.git
            case yapf
                set git_urls https://github.com/google/yapf
        end

        ########################
        # SOURCE BASED INSTALL #
        ########################
        if test -n "$git_urls"
            for git_url in $git_urls
                set src_base $BIN_SRC_FOLDER
                if test -n "$subfolder"
                    set src_base $BIN_SRC_FOLDER/$subfolder
                end
                set src $src_base/(string replace ".git" "" (basename $git_url))
                if not test -d $src
                    mkdir -p (dirname $src)
                    git clone $git_clone_args $git_url $src; or return
                end
                git -C $src pull -r; or return
                if test "$submodules" = true
                    git -C $src submodule update --recursive; or return
                end
            end
        else
            ####################################
            # PREBUILT OR PODMAN BASED INSTALL #
            ####################################
            set work_dir (mktemp -d)
            pushd $work_dir; or return

            set binary $BIN_FOLDER/$target

            switch (uname -m)
                case aarch64
                    if command -q dpkg
                        # Because 32-bit Raspberry Pi OS with a 64-bit kernel...
                        switch (dpkg --print-architecture)
                            case armhf
                                set arch arm
                            case '*'
                                set arch arm64
                        end
                    else
                        set arch arm64
                    end
                case armv7l
                    set arch arm
                case x86_64
                    set arch x86_64
            end

            switch $arch
                case arm
                    set rust_triple arm-unknown-linux-gnueabihf
                case arm64
                    set rust_triple aarch64-unknown-linux-gnu
                case x86_64
                    set rust_triple x86_64-unknown-linux-gnu
            end

            switch $target
                case bat diskus fd hyperfine
                    set repo sharkdp/$target
                    set ver (glr $repo)

                    set url https://github.com/$repo/releases/download/$ver/$target-$ver-$rust_triple.tar.gz

                    crl $url | tar -xzf -; or return
                    cd (string replace ".tar.gz" "" (basename $url)); or return

                    install -Dvm755 $target $binary
                    switch $target
                        case bat fd hyperfine
                            install -Dvm644 autocomplete/$target.fish $__fish_config_dir/completions/$target.fish
                    end

                case duf
                    switch $arch
                        case arm
                            set arch armv7
                    end

                    set repo muesli/duf
                    set ver (glr $repo)
                    set url https://github.com/$repo/releases/download/$ver/duf_(string replace "v" "" $ver)_linux_$arch.tar.gz

                    crl $url | tar -C $work_dir -xzf -; or return

                    install -Dvm755 $work_dir/duf $binary

                case exa
                    switch (uname -m)
                        case x86_64
                            set repo ogham/exa
                            set ver (glr $repo)
                            set url https://github.com/$repo/releases/download/$ver/exa-linux-x86_64-$ver.zip

                            crl -O $url; or return
                            unzip (basename $url); or return

                            install -Dvm755 bin/exa $binary
                            install -Dvm644 completions/exa.fish $__fish_config_dir/completions/exa.fish
                    end

                case hub
                    switch $arch
                        case x86_64
                            set arch amd64
                    end

                    set repo github/hub
                    set ver (glr $repo)
                    set url https://github.com/$repo/releases/download/$ver/hub-linux-$arch-(string replace "v" "" $ver).tgz

                    crl $url | tar -xzf -
                    cd (string replace ".tgz" "" (basename $url)); or return

                    install -Dvm755 bin/hub $binary
                    install -Dvm644 etc/hub.fish_completion $__fish_config_dir/completions/hub.fish
                    install -Dvm644 share/vim/vimfiles/ftdetect/pullrequest.vim $HOME/.vim/ftdetect/pullrequest.vim
                    install -Dvm644 share/vim/vimfiles/syntax/pullrequest.vim $HOME/.vim/syntax/pullrequest.vim

                case repo
                    mkdir -p (dirname $binary)
                    crl -o $binary https://storage.googleapis.com/git-repo-downloads/repo
                    chmod a+x $binary

                case rg
                    switch $arch
                        case arm arm64
                            set repo microsoft/ripgrep-prebuilt
                            set ver (glr $repo)
                            set url https://github.com/$repo/releases/download/$ver/ripgrep-$ver-$rust_triple.tar.gz

                            crl $url | tar -xzf -; or return

                            install -Dvm755 rg $binary

                        case x86_64
                            set repo BurntSushi/ripgrep
                            set ver (glr $repo)
                            set url https://github.com/$repo/releases/download/$ver/ripgrep-$ver-x86_64-unknown-linux-musl.tar.gz

                            crl $url | tar -xzf -; or return
                            cd (string replace '.tar.gz' '' (basename $url)); or return

                            install -Dvm755 rg $binary
                            install -Dvm644 complete/rg.fish $__fish_config_dir/completions/rg.fish
                    end

                case shellcheck
                    switch $arch
                        case arm
                            set arch armv6hf
                        case arm64
                            set arch aarch64
                    end

                    set repo koalaman/shellcheck
                    set ver (glr $repo)
                    set url https://github.com/$repo/releases/download/$ver/shellcheck-$ver.linux.$arch.tar.xz

                    crl $url | tar -xJf -
                    cd shellcheck-$ver; or return

                    install -Dvm755 shellcheck $binary

                case shfmt
                    switch $arch
                        case x86_64
                            set arch amd64
                    end

                    set repo mvdan/sh
                    set ver (glr $repo)
                    set url https://github.com/$repo/releases/download/$ver/shfmt_"$ver"_linux_$arch

                    mkdir -p (dirname $binary)
                    crl -o $binary $url
                    chmod +x $binary

                case dev lei strip
                    boci $target
            end

            popd
            rm -rf $work_dir

            if test -x $binary
                $binary --version; or return
            end
        end
    end
end
