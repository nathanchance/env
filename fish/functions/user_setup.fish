#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function user_setup -d "Setup a user account, downloading all files and placing them where they need to go"
    # If we are using GNOME Terminal, the "Unnamed" profile needs to be set
    if is_installed gnome-terminal
        set gnome_prof_dir /org/gnome/terminal/legacy/profiles:/
        set gnome_prof_base :(dconf dump $gnome_prof_dir | grep "list=" | cut -d \' -f 2)
        if test "$gnome_prof_base" = ""
            set gnome_prof_base (dconf dump $gnome_prof_dir | head -1 | awk -F '[][]' '{print $2}')
            if test "$gnome_prof_base" = ""
                print_error "Rename 'Unnamed' profile in GNOME Terminal before running this function"
                return 1
            end
        end
        set gnome_prof $gnome_prof_dir$gnome_prof_base/
    end

    if uname -r | grep -iq microsoft
        set wsl true
    end

    if command -q yay
        yay --sudo doas --sudoflags -- --save
    end

    if test "$LOCATION" = server; or test "$LOCATION" = wsl
        set trusted true
    end

    if test "$trusted" = true
        if test "$wsl" = true
            set keys_folder /mnt/c/Users/natec/Documents/Keys
        else
            set keys_folder /tmp/keys
        end

        set ssh_folder $HOME/.ssh
        if not test -f $ssh_folder/id_ed25519
            mkdir -p $ssh_folder
            if not test -d $keys_folder
                git clone https://github.com/nathanchance/keys $keys_folder; or return
            end

            set ssh_keys $keys_folder/ssh
            cp -v $ssh_keys/id_ed25519{,.pub} $ssh_folder
            cp -v $ssh_keys/korg-nathan $ssh_folder/id_korg
            chmod 600 $ssh_folder/id_{ed25519,korg}
            echo 'Host gitolite.kernel.org
  User git
  IdentityFile ~/.ssh/id_korg
  IdentitiesOnly yes
  ClearAllForwardings yes
  # We prefer ed25519 keys, but will fall back to others if your
  # openssh client does not support that
  HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp256,ssh-rsa
  # Below are very useful for speeding up repeat access
  # and for 2-factor validating your sessions
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlMaster auto
  ControlPersist 30m
  # Helps behind some NAT-ing routers
  ServerAliveInterval 60' >>$ssh_folder/config
        end

        if not gpg_key_usable
            if not test -d $keys_folder
                git clone https://github.com/nathanchance/keys $keys_folder; or return
            end

            gpg --pinentry-mode loopback --import $keys_folder/encryption/private.asc; or return
            gpg --pinentry-mode loopback --import $keys_folder/signing/private.asc; or return
            gpg --import $keys_folder/main/public.asc
            gpg --import-ownertrust $keys_folder/main/ownertrust*.asc
            echo "default-cache-ttl 604800" >>$HOME/.gnupg/gpg-agent.conf
            echo "max-cache-ttl 2419200" >>$HOME/.gnupg/gpg-agent.conf
            gpg-connect-agent reloadagent /bye
        end

        if test "$wsl" != true
            rm -rf $keys_folder
        end

        gpg_key_cache; or return

        if test -f $HOME/.ssh/.ssh-agent.fish
            ssh_agent; or return
        else
            if not ssh-add -l
                ssh-add $HOME/.ssh/id_ed25519; or return
            end
        end
        set github_prefix git@github.com:
    else
        set github_prefix https://github.com/
    end

    if not test -d $ENV_FOLDER
        mkdir -p (dirname $ENV_FOLDER)
        git clone "$github_prefix"nathanchance/env.git $ENV_FOLDER; or return
    end
    git -C $ENV_FOLDER pull
    set hydro $GITHUB_FOLDER/hydro
    if not test -d $hydro
        mkdir -p (dirname $hydro)
        git clone -b me "$github_prefix"nathanchance/hydro.git $hydro; or return
        git -C $hydro remote add upstream https://github.com/jorgebucaran/hydro.git
    end
    git -C $hydro remote update

    fisher remove /tmp/env/fish
    fisher install $ENV_FOLDER/fish
    fisher install $hydro
    rm -rf $__fish_config_dir/config.fish
    ln -fsv $ENV_FOLDER/fish/config.fish $__fish_config_dir/config.fish

    # fish colors
    set -U fish_color_normal normal
    set -U fish_color_command blue
    set -U fish_color_quote yellow
    set -U fish_color_redirection green
    set -U fish_color_end green
    set -U fish_color_error red
    set -U fish_color_param cyan
    set -U fish_color_comment brblack
    set -U fish_color_match normal
    set -U fish_color_selection 97979b
    set -U fish_color_search_match yellow
    set -U fish_color_history_current normal
    set -U fish_color_operator magenta
    set -U fish_color_escape magenta
    set -U fish_color_cwd blue
    set -U fish_color_cwd_root blue
    set -U fish_color_valid_path normal
    set -U fish_color_autosuggestion 97979b
    set -U fish_color_user yellow
    set -U fish_color_host green
    set -U fish_color_cancel normal
    set -U fish_pager_color_completion normal
    set -U fish_pager_color_description B3A06D yellow
    set -U fish_pager_color_prefix white --bold --underline
    set -U fish_pager_color_progress brwhite --background=cyan

    # hydro colors
    set -U hydro_color_user yellow
    set -U hydro_color_at green
    set -U hydro_color_host green
    set -U hydro_color_pwd blue
    set -U hydro_color_git magenta
    set -U hydro_color_duration yellow
    set -U hydro_color_prompt green

    set gitignore $HOME/.gitignore_global
    git config --global core.excludesfile $gitignore
    crl -o $gitignore https://gist.githubusercontent.com/octocat/9257657/raw/3f9569e65df83a7b328b39a091f0ce9c6efc6429/.gitignore
    echo '
# Personal exclusions #
#######################
build/
out.*/
*.rej' >>$gitignore

    rbld_usr; or return
    fish_add_path -m $USR_FOLDER/bin

    ccache_setup
    git_setup

    set configs $ENV_FOLDER/configs

    bash $configs/common/vim/vim_setup.bash

    if test "$wsl" != true; and not set -q DISPLAY
        ln -fsv $configs/headless/.tmux.conf $HOME/.tmux.conf
    end

    if set -q DISPLAY
        if is_installed gnome-terminal
            dconf load $gnome_prof <$configs/local/Nathan.dconf
        end

        if is_installed google-chrome
            echo "--enable-features=WebUIDarkMode
--force-dark-mode" >$HOME/.config/chrome-flags.conf
        end

        if is_installed konsole
            set konsole_share $HOME/.local/share/konsole
            mkdir -p $konsole_share
            ln -fsv $configs/local/Nathan.profile $konsole_share/Nathan.profile
            ln -fsv $configs/local/snazzy.colorscheme $konsole_share/snazzy.colorscheme
        end

        if is_installed xfce4-terminal
            set xfce_share $HOME/.local/share/xfce4/terminal/colorschemes
            mkdir -p $xfce_share
            ln -fsv $configs/local/snazzy.theme $xfce_share
        end
    end

    if test "$trusted" = true
        decrypt_gpg_file botinfo
        decrypt_gpg_file muttrc
        decrypt_gpg_file config.ini $HOME/.config/tuxsuite/config.ini

        hub api; or return
    end

    if test "$wsl" = true
        decrypt_gpg_file server_ip

        set github_repos hugo-files nathanchance.github.io
    else if test "$trusted" = true
        mkdir -p $ANDROID_TC_FOLDER
        if not test -d $ANDROID_TC_FOLDER/clang-master
            tmux new-window fish -c "git -C $ANDROID_TC_FOLDER clone --single-branch https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/ clang-master"
        end
        if not test -d $ANDROID_TC_FOLDER/gcc-arm
            git -C $ANDROID_TC_FOLDER clone --depth=1 -b android-9.0.0_r1 --single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/ gcc-arm
        end
        if not test -d $ANDROID_TC_FOLDER/gcc-arm64
            git -C $ANDROID_TC_FOLDER clone --depth=1 -b android-9.0.0_r1 --single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/ gcc-arm64
        end

        mkdir -p $SRC_FOLDER
        if not test -d $SRC_FOLDER/android-wireguard-module-builder
            git -C $SRC_FOLDER clone git@github.com:WireGuard/android-wireguard-module-builder.git
        end
        if not test -d $SRC_FOLDER/pahole
            git -C $SRC_FOLDER clone https://git.kernel.org/pub/scm/devel/pahole/pahole.git
        end

        set github_repos bug-files hugo-files nathanchance.github.io patches

        for linux_tree in linux linux-next linux-stable
            tmux new-window fish -c "cbl_linux_repos $linux_tree; sleep 180"
        end

        tmux new-window fish -c "ssh_agent; and cbl_other_repos; sleep 180"
    else
        return 0
    end

    mkdir -p $GITHUB_FOLDER
    for github_repo in $github_repos
        set folder $GITHUB_FOLDER/$github_repo
        if not test -d $folder
            hub clone $github_repo $folder; or return
        end
    end
    git -C $GITHUB_FOLDER/hugo-files submodule update --init --recursive
end
