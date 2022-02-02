#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

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

    # Set WSL and "trusted environment" variables to make decisions later
    if uname -r | grep -iq microsoft
        set wsl true
    end
    if test "$LOCATION" = server; or test "$LOCATION" = wsl
        set trusted true
    end

    # GPG and SSH keys (trusted environment only)
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
            start_ssh_agent; or return
        else
            if not ssh-add -l
                ssh-add $HOME/.ssh/id_ed25519; or return
            end
        end
        set github_prefix git@github.com:
    else
        set github_prefix https://github.com/
    end

    # Downloading/updating environment scripts and prompt
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

    # Set up fish environment with fisher
    if fisher list &| grep -q /tmp/env/fish
        fisher remove /tmp/env/fish
    end
    fisher install $ENV_FOLDER/fish; or return
    fisher install $hydro; or return
    if not command -q zoxide
        fisher install jethrokuan/z; or return
    end
    fisher install PatrickF1/fzf.fish; or return
    rm -rf $__fish_config_dir/config.fish
    ln -fsv $ENV_FOLDER/fish/config.fish $__fish_config_dir/config.fish

    # Global .gitignore
    set gitignore $HOME/.gitignore_global
    git config --global core.excludesfile $gitignore
    crl -o $gitignore https://gist.githubusercontent.com/octocat/9257657/raw/3f9569e65df83a7b328b39a091f0ce9c6efc6429/.gitignore
    echo '
# Personal exclusions #
#######################
build/
.build/
out.*/
*.rej' >>$gitignore

    # Ensure podman registers with correct options for environment
    if command -q podman
        podman info
    end

    # Binaries
    if test (get_distro) = arch
        clone_aur_repos
        set aur_pkgs opendoas-sudo
        if test "$wsl" != true
            set -a aur_pkgs modprobed-db
        end
        for $aur_pkg in $aur_pkgs
            if not is_installed $aur_pkg
                pushd $AUR_FOLDER/$aur_pkg; or return
                makepkg; or return
                doas pacman -U --noconfirm $aur_pkg*.pkg.tar.zst; or return
                popd
            end
        end
        if is_installed modprobed-db
            modprobed-db
            modprobed-db store
            systemctl --user enable --now modprobed-db.service
        end
    end
    updall --no-os; or return

    # Git config and aliases
    git_setup

    # Configuration files (vim, tmux, etc)
    set configs $ENV_FOLDER/configs
    bash $configs/common/vim/vim_setup.bash
    ln -fsv $configs/headless/.tmux.conf $HOME/.tmux.conf

    # Terminal profiles
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

    # Private configuration files
    if test "$trusted" = true
        decrypt_gpg_file botinfo
        decrypt_gpg_file muttrc
        decrypt_gpg_file muttrc.notifier
        decrypt_gpg_file config.ini $HOME/.config/tuxsuite/config.ini

        gh auth login; or return
    end

    # git repos and source folders
    if test "$wsl" = true
        decrypt_gpg_file server_ip

        set github_repos hugo-files nathanchance.github.io
    else if test "$trusted" = true
        mkdir -p $SRC_FOLDER

        set github_repos bug-files hugo-files nathanchance.github.io patches

        for linux_tree in linux linux-next linux-stable
            tmux new-window fish -c "cbl_setup_linux_repos $linux_tree; sleep 180"
        end

        tmux new-window fish -c "start_ssh_agent; and cbl_setup_other_repos; sleep 180"
    else
        return 0
    end

    mkdir -p $GITHUB_FOLDER
    for github_repo in $github_repos
        set folder $GITHUB_FOLDER/$github_repo
        if not test -d $folder
            gh repo clone $github_repo $folder; or return
        end
        if test "$github_repo" = hugo-files
            git -C $folder submodule update --init --recursive
        end
    end
end
