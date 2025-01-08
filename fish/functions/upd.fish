#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function upd -d "Runs the update command for the current distro or downloads/updates requested binary"
    for arg in $argv
        switch $arg
            case -f --force
                set force true
            case -y --yes
                set yes -y
            case '*'
                set -a targets $arg
        end
    end

    if not set -q targets
        set targets os
    end

    for target in $targets
        switch $target
            case env
                if not is_location_primary
                    git -C $ENV_FOLDER pull -qr; or return
                    rld
                end
                continue

            case fisher
                fisher_update 1>/dev/null; or return
                continue

            case hydro
                set repo $GITHUB_FOLDER/$target
                if is_location_primary
                    switch $target
                        case hydro
                            set branch main
                            set owner jorgebucaran
                    end
                    gh repo sync --force --source $owner/$target nathanchance/$target; or return
                    git -C $repo ru --prune; or return
                    git -C $repo rb upstream/$branch; or return
                else
                    git -C $repo urh; or return
                end
                switch $target
                    case hydro
                        fisher_update $repo 1>/dev/null; or return
                end

            case forks
                set fisher_plugins \
                    jorgebucaran/autopair.fish \
                    PatrickF1/fzf.fish \
                    wfxr/forgit
                set vim_plugins \
                    blankname/vim-fish \
                    junegunn/fzf.vim \
                    tpope/vim-fugitive \
                    vivien/vim-linux-coding-style

                set forked_repos \
                    $fisher_plugins \
                    $vim_plugins

                for forked_repo in $forked_repos
                    set -l repo_name (basename $forked_repo)
                    set -l repo_path $FORKS_FOLDER/$repo_name
                    if test -d $repo_path
                        gh repo sync --force --source $forked_repo nathanchance/$repo_name
                        git -C $repo_path urh
                    else
                        mkdir -p (dirname $forked_repo)
                        gh repo fork --clone $forked_repo $repo_path
                    end
                end
                continue

            case os os-no-container
                $PYTHON_SCRIPTS_FOLDER/upd_distro.py $yes
                if test "$target" != os-no-container; and test $LOCATION != mac
                    sd_nspawn -r "$PYTHON_SCRIPTS_FOLDER/upd_distro.py $yes"
                end
                if command -q mac
                    mac orb update
                end
                continue

            case tmuxp
                if in_container
                    print_warning "tmuxp should be installed while in the host environment, skipping..."
                else
                    if command -q tmuxp; and test "$force" != true
                        print_warning "tmuxp is installed through package manager, skipping..."
                    else
                        set -l tmuxp_tmp (mktemp -d)
                        set -l tmuxp_prefix $BIN_FOLDER/tmuxp
                        python3 -m pip install --target $tmuxp_tmp tmuxp
                        rm -fr $tmuxp_prefix
                        mv $tmuxp_tmp $tmuxp_prefix
                    end
                end
                continue

            case vim
                set vim_plugins \
                    https://github.com/blankname/vim-fish \
                    https://github.com/junegunn/fzf.vim \
                    https://github.com/tpope/vim-fugitive \
                    https://github.com/vivien/vim-linux-coding-style

                for vim_plugin in $vim_plugins
                    set dest $HOME/.vim/pack/my-plugins/start/(basename $vim_plugin)
                    if test -d $dest
                        git -C $dest pull
                    else
                        mkdir -p (dirname dest)
                        git clone $vim_plugin $dest
                    end
                end
                continue
        end

        # These need to be local to the loop so they are reset each invocation
        set -l git_clone_args
        set -l git_urls
        set -l subfolder
        set -l submodules

        switch $target
            case b4 bat btop diskus duf exa fd fzf hyperfine repo rg shellcheck shfmt tuxmake yapf
                if command -q $target; and test "$force" != true
                    print_warning "$target is installed through package manager, skipping install..."
                    continue
                end
        end

        ########################
        # SOURCE BASED INSTALL #
        ########################
        switch $target
            case b4
                set git_clone_args --recursive
                set git_urls https://git.kernel.org/pub/scm/utils/b4/b4.git
                set submodules true
            case tuxmake
                set git_urls https://gitlab.com/Linaro/tuxmake.git
            case yapf
                set git_urls https://github.com/google/yapf
        end

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
            if in_container
                set binary /usr/local/bin/$target
                set completions $__fish_sysconf_dir/completions

                set chmod sudo chmod
                set curl sudo curl -LSs
                set install sudo install
                set mkdir sudo mkdir

                sudo true; or return
            else
                set binary $BIN_FOLDER/$target
                set completions $__fish_config_dir/completions

                set chmod chmod
                set curl curl -LSs
                set install install
                set mkdir mkdir
            end

            set work_dir (mktemp -d)
            pushd $work_dir; or return

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
                    if test (get_glibc_version) -lt 22900
                        print_warning "$target requires glibc 2.29 or newer, skipping..."
                        continue
                    end
                    set repo sharkdp/$target
                    set ver (glr $repo)

                    set url https://github.com/$repo/releases/download/$ver/$target-$ver-$rust_triple.tar.gz

                    crl $url | tar -xzf -; or return
                    cd (string replace ".tar.gz" "" (basename $url)); or return

                    $install -Dvm755 $target $binary
                    switch $target
                        case bat fd hyperfine
                            $install -Dvm644 autocomplete/$target.fish $completions/$target.fish
                    end

                case btop
                    switch $arch
                        case arm
                            set btop_triple arm-linux-musleabi
                        case arm64
                            set btop_triple aarch64-linux-musl
                        case x86_64
                            set btop_triple x86_64-linux-musl
                    end

                    set repo aristocratos/btop
                    set ver (glr $repo)

                    set url https://github.com/$repo/releases/download/$ver/btop-$btop_triple.tbz

                    crl $url | tar -xjf -; or return

                    set -l prefix
                    if in_container
                        set prefix /usr/local
                    else
                        set prefix $BIN_FOLDER/btop
                        rm -fr $prefix
                    end
                    $install -Dvm755 -t $prefix/bin $target/bin/$target
                    for theme in $target/themes/*
                        $install -Dvm755 -t $prefix/share/btop/themes $theme
                    end
                    set binary $prefix/bin/$target

                case duf
                    switch $arch
                        case arm
                            set arch armv7
                    end

                    set repo muesli/duf
                    set ver (glr $repo)
                    set url https://github.com/$repo/releases/download/$ver/duf_(string replace "v" "" $ver)_linux_$arch.tar.gz

                    crl $url | tar -C $work_dir -xzf -; or return

                    $install -Dvm755 $work_dir/duf $binary

                case exa
                    switch (uname -m)
                        case x86_64
                            set repo ogham/exa
                            set ver (glr $repo)
                            set url https://github.com/$repo/releases/download/$ver/exa-linux-x86_64-$ver.zip

                            crl -O $url; or return
                            unzip (basename $url); or return

                            $install -Dvm755 bin/exa $binary
                            $install -Dvm644 completions/exa.fish $completions/exa.fish
                    end

                case eza
                    set repo eza-community/eza
                    set ver (glr $repo)
                    set url https://github.com/$repo/releases/download/$ver/eza_$rust_triple.zip

                    crl -O $url; or return
                    unzip (basename $url); or return

                    $install -Dvm755 ./eza $binary

                case fzf
                    switch $arch
                        case arm
                            set arch armv7
                        case x86_64
                            set arch amd64
                    end

                    set repo junegunn/fzf
                    set ver (glr $repo)
                    set url https://github.com/$repo/releases/download/$ver/fzf-$ver-linux_$arch.tar.gz

                    crl $url | tar -xzf -
                    $install -Dvm755 fzf $binary

                case gh
                    switch $arch
                        case arm
                            set arch armv6
                        case x86_64
                            set arch amd64
                    end

                    set repo cli/cli
                    set ver (glr $repo)
                    set url https://github.com/$repo/releases/download/$ver/gh_(string replace "v" "" $ver)_linux_$arch.tar.gz

                    crl $url | tar -xzf -
                    cd (string replace ".tar.gz" "" (basename $url)); or return

                    $install -Dvm755 bin/gh $binary

                case iosevka
                    if in_container
                        print_error "Iosevka should be installed on the host, not the container!"
                        continue
                    end

                    set repo be5invis/Iosevka
                    set ver (glr $repo)
                    set url https://github.com/$repo/releases/download/$ver/super-ttc-iosevka-ss08-(string replace "v" "" $ver).zip

                    crl -O $url; or return
                    unzip (basename $url); or return

                    install -Dvm644 iosevka-ss08.ttc $HOME/.local/share/fonts/iosevka-ss08.ttc
                    fc-cache -fv

                case repo
                    if not command -q python
                        print_warning "$target requires an unversioned python binary, skipping..."
                        continue
                    end
                    $mkdir -p (dirname $binary)
                    $curl -o $binary https://storage.googleapis.com/git-repo-downloads/repo
                    $chmod a+x $binary

                case rg
                    switch $arch
                        case arm arm64
                            set repo microsoft/ripgrep-prebuilt
                            set ver (glr $repo)
                            set url https://github.com/$repo/releases/download/$ver/ripgrep-$ver-$rust_triple.tar.gz

                            crl $url | tar -xzf -; or return

                            $install -Dvm755 rg $binary

                        case x86_64
                            set repo BurntSushi/ripgrep
                            set ver (glr $repo)
                            set url https://github.com/$repo/releases/download/$ver/ripgrep-$ver-x86_64-unknown-linux-musl.tar.gz

                            crl $url | tar -xzf -; or return
                            cd (string replace '.tar.gz' '' (basename $url)); or return

                            $install -Dvm755 rg $binary
                            $install -Dvm644 complete/rg.fish $completions/rg.fish
                    end

                case rustup
                    if test $LOCATION = mac
                        print_error "$target should be installed via homebrew!"
                        return 1
                    end
                    curl --proto '=https' --tlsv1.3 -sSf https://sh.rustup.rs | sh

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

                    $install -Dvm755 shellcheck $binary

                case shfmt
                    switch $arch
                        case x86_64
                            set arch amd64
                    end

                    set repo mvdan/sh
                    set ver (glr $repo)
                    set url https://github.com/$repo/releases/download/$ver/shfmt_"$ver"_linux_$arch

                    $mkdir -p (dirname $binary)
                    $curl -o $binary $url
                    $chmod +x $binary

                case wally-cli
                    set repo zsa/wally-cli
                    set ver (glr $repo)
                    set url https://github.com/$repo/releases/download/$ver/wally-cli

                    $mkdir -p (dirname $binary)
                    $curl -o $binary $url
                    $chmod +x $binary

                case dev lei
                    oci_bld $target
            end

            popd
            rm -rf $work_dir

            if test -x $binary
                $binary --version; or return
            end
        end
    end
end
