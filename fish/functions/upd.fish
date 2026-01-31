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
            case bat btop diskus duf eza fd fzf hyperfine repo rg shellcheck shfmt tmuxp zoxide
                if test $LOCATION = mac
                    __print_warning "$target should be installed and updated via Homebrew, skipping..."
                    continue
                end
                if __is_system_binary $target; and test "$force" != true
                    __print_warning "$target is installed through package manager, skipping..."
                    continue
                end
        end

        switch $target
            case env
                if not __is_location_primary
                    git -C $ENV_FOLDER pull -qr
                    or return

                    rld
                end
                continue

            case fisher
                fisher_update 1>/dev/null
                or return
                continue

            case hydro
                set repo $GITHUB_FOLDER/$target
                if __is_location_primary
                    switch $target
                        case hydro
                            set branch main
                            set owner jorgebucaran
                    end
                    begin
                        gh repo sync --force --source $owner/$target nathanchance/$target
                        and git -C $repo ru --prune
                        and git -C $repo rb upstream/$branch
                    end
                    or return
                else
                    git -C $repo urh
                    or return
                end
                switch $target
                    case hydro
                        fisher_update $repo 1>/dev/null
                        or return
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
                    set -l repo_name (path basename $forked_repo)
                    set -l repo_path $FORKS_FOLDER/$repo_name
                    if test -d $repo_path
                        gh repo sync --force --source $forked_repo nathanchance/$repo_name
                        git -C $repo_path urh
                    else
                        mkdir -p (path dirname $forked_repo)
                        gh repo fork --clone $forked_repo $repo_path
                    end
                end
                continue

            case os os-no-container
                $PYTHON_SCRIPTS_FOLDER/upd_distro.py $yes
                or return

                if test "$target" != os-no-container; and not __in_container; and test $LOCATION != mac
                    sd_nspawn -r "$PYTHON_SCRIPTS_FOLDER/upd_distro.py $yes"
                    or return
                end

                continue

            case tmuxp
                if __in_container
                    __print_warning "tmuxp should be installed while in the host environment, skipping..."
                    continue
                end

                set -l tmuxp_tmp (mktemp -d)
                python3 -m pip install --target $tmuxp_tmp tmuxp
                or return

                set -l tmuxp_prefix $BIN_FOLDER/tmuxp
                rm -fr $tmuxp_prefix
                mv -v $tmuxp_tmp $tmuxp_prefix
                or return

                env PYTHONPATH=$tmuxp_prefix $tmuxp_prefix/bin/tmuxp --version
                or return

                continue

            case vim
                set vim_plugins \
                    https://github.com/blankname/vim-fish \
                    https://github.com/junegunn/fzf.vim \
                    https://github.com/tpope/vim-fugitive \
                    https://github.com/vivien/vim-linux-coding-style

                for vim_plugin in $vim_plugins
                    set dest $HOME/.vim/pack/my-plugins/start/(path basename $vim_plugin)
                    if test -d $dest
                        git -C $dest pull
                    else
                        mkdir -p (path dirname dest)
                        git clone $vim_plugin $dest
                    end
                end
                continue
        end

        # These need to be local to the loop so they are reset each invocation
        set -l subfolder

        if __in_container
            set binary /usr/local/bin/$target
            set completions $__fish_sysconf_dir/completions
            set man /usr/local/man

            set install run0 install

            request_root "Installing software within container"
            or return
        else
            set binary $BIN_FOLDER/$target
            set completions $__fish_user_data_dir/vendor_completions.d
            set man $HOME/.local/share/man

            set install install
        end

        set work_dir (mktemp -d)
        pushd $work_dir
        or return

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
                if test (__get_glibc_version) -lt 22900
                    __print_warning "$target requires glibc 2.29 or newer, skipping..."
                    continue
                end
                set repo sharkdp/$target
                set ver (glr $repo)

                set url https://github.com/$repo/releases/download/$ver/$target-$ver-$rust_triple.tar.gz

                begin
                    crl $url | tar -xzf -
                    and cd (path basename $url | string replace ".tar.gz" "")
                    and $install -Dvm755 $target $binary
                end
                or return

                switch $target
                    case bat fd hyperfine
                        $install -Dvm644 autocomplete/$target.fish $completions/$target.fish
                        or return
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

                crl $url | tar -xjf -
                or return

                set -l prefix
                if __in_container
                    set prefix /usr/local
                else
                    set prefix $BIN_FOLDER/btop
                    rm -fr $prefix
                end

                $install -Dvm755 -t $prefix/bin $target/bin/$target
                or return

                for theme in $target/themes/*
                    $install -Dvm755 -t $prefix/share/btop/themes $theme
                    or return
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

                crl $url | tar -C $work_dir -xzf -
                or return

                $install -Dvm755 $work_dir/duf $binary
                or return

            case eza
                set repo eza-community/eza
                set ver (glr $repo)
                set url https://github.com/$repo/releases/download/$ver/eza_$rust_triple.zip

                begin
                    crl -O $url
                    and unzip (path basename $url)
                    and $install -Dvm755 ./eza $binary
                end
                or return

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
                or return

                $install -Dvm755 fzf $binary
                or return

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

                begin
                    crl $url | tar -xzf -
                    and cd (path basename $url | string replace ".tar.gz" "")
                    and $install -Dvm755 bin/gh $binary
                end
                or return

            case iosevka
                if __in_container
                    __print_warning "Iosevka should be installed on the host, not the container, skipping..."
                    continue
                end

                set repo be5invis/Iosevka
                set ver (glr $repo)
                set url https://github.com/$repo/releases/download/$ver/super-ttc-iosevka-ss08-(string replace "v" "" $ver).zip

                begin
                    crl -O $url
                    and unzip (path basename $url)

                    and install -Dvm644 iosevka-ss08.ttc $HOME/.local/share/fonts/iosevka-ss08.ttc
                    and fc-cache -fv
                end
                or return

            case repo
                if not command -q python
                    __print_warning "$target requires an unversioned python binary, skipping..."
                    continue
                end
                crl https://storage.googleapis.com/git-repo-downloads/repo | $install -Dvm755 /dev/stdin $binary

            case rg
                switch $arch
                    case arm arm64
                        set repo microsoft/ripgrep-prebuilt
                        set ver (glr $repo)
                        set url https://github.com/$repo/releases/download/$ver/ripgrep-$ver-$rust_triple.tar.gz

                        crl $url | tar -xzf -
                        or return

                        $install -Dvm755 rg $binary
                        or return

                    case x86_64
                        set repo BurntSushi/ripgrep
                        set ver (glr $repo)
                        set url https://github.com/$repo/releases/download/$ver/ripgrep-$ver-x86_64-unknown-linux-musl.tar.gz

                        begin
                            crl $url | tar -xzf -
                            and cd (path basename $url | string replace '.tar.gz' '')

                            and $install -Dvm755 rg $binary
                            and $install -Dvm644 complete/rg.fish $completions/rg.fish
                        end
                        or return
                end

            case rustup
                if test $LOCATION = mac
                    __print_error "$target should be installed via homebrew!"
                    return 1
                end
                curl --proto '=https' --tlsv1.3 -sSf https://sh.rustup.rs | sh
                or return

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

                begin
                    crl $url | tar -xJf -
                    and cd shellcheck-$ver
                    and $install -Dvm755 shellcheck $binary
                end
                or return

            case shfmt
                switch $arch
                    case x86_64
                        set arch amd64
                end

                set repo mvdan/sh
                set ver (glr $repo)

                crl https://github.com/$repo/releases/download/$ver/shfmt_"$ver"_linux_$arch | $install -Dvm755 /dev/stdin $binary
                or return

            case vmtest
                switch $arch
                    case aarch64 x86_64
                        # pass
                    case '*'
                        __print_warning "$target is only available for x86_64, build from source if required..."
                        continue
                end

                set repo danobi/vmtest
                set ver (glr $repo)

                crl https://github.com/$repo/releases/download/$ver/vmtest-$arch | $install -Dvm755 /dev/stdin $binary
                or return

            case zoxide
                switch $arch
                    case arm
                        set arch armv7
                        set triple_os musleabihf
                    case '*'
                        set triple_os musl
                end

                set repo ajeetdsouza/zoxide
                set ver (glr $repo)
                set url https://github.com/$repo/releases/download/$ver/zoxide-(string replace v '' $ver)-$arch-unknown-linux-$triple_os.tar.gz

                begin
                    crl $url | tar -xzf -
                    and $install -Dvm755 zoxide $binary
                    and $install -Dvm644 -t $man/man1 man/man1/*.1
                    and $install -Dvm644 {completions,$completions}/zoxide.fish
                end
                or return
        end

        popd
        rm -rf $work_dir

        if test -x $binary
            $binary --version
            or return
        end
    end
end
