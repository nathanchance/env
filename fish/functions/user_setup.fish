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

    # Set "trusted environment" variable to make decisions later
    switch $LOCATION
        case hetzner-server wsl
            set trusted_gpg true
            set trusted_ssh true
        case pi test-desktop-amd test-laptop-intel
            set trusted_ssh true
    end

    # Trusting an environment with GPG but not SSH makes little sense
    if test "$trusted_gpg" = true; and not test "$trusted_ssh" = true
        print_error "This environment trusts GPG but not SSH?"
        return 1
    end

    # Set up where keys should be available
    switch $LOCATION
        case wsl
            set keys_folder /mnt/c/Users/natec/Documents/Keys
        case '*'
            set keys_folder /tmp/keys
    end

    # Set up SSH keys if requested
    if test "$trusted_ssh" = true
        # Set up gh
        if not gh auth status
            gh auth login; or return
        end
        set use_gh true

        set ssh_folder $HOME/.ssh
        if not test -f $ssh_folder/id_ed25519
            mkdir -p $ssh_folder
            if not test -d $keys_folder
                gh repo clone keys $keys_folder; or return
            end

            set ssh_keys $keys_folder/ssh
            cp -v $ssh_keys/id_ed25519{,.pub} $ssh_folder
            cp -v $ssh_keys/korg-nathan $ssh_folder/id_korg
            chmod 600 $ssh_folder/id_{ed25519,korg}
            # https://korg.docs.kernel.org/access.html#if-you-received-a-ssh-private-key-from-kernel-org
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

        if test -f $HOME/.ssh/.ssh-agent.fish
            start_ssh_agent; or return
        else
            if not ssh-add -l
                ssh-add $HOME/.ssh/id_ed25519; or return
            end
        end
    end

    if test "$trusted_gpg" = true
        if not gpg_key_usable
            if not test -d $keys_folder
                gh repo clone keys $keys_folder; or return
            end

            gpg --pinentry-mode loopback --import $keys_folder/encryption/private.asc; or return
            gpg --pinentry-mode loopback --import $keys_folder/signing/private.asc; or return
            gpg --import $keys_folder/main/public.asc
            gpg --import-ownertrust $keys_folder/main/ownertrust*.asc
            echo "default-cache-ttl 604800" >>$HOME/.gnupg/gpg-agent.conf
            echo "max-cache-ttl 2419200" >>$HOME/.gnupg/gpg-agent.conf
            gpg-connect-agent reloadagent /bye
        end

        gpg_key_cache; or return
    end

    if test "$LOCATION" != wsl
        rm -rf $keys_folder
    end

    # Downloading/updating environment scripts and prompt
    if not test -d $ENV_FOLDER
        mkdir -p (dirname $ENV_FOLDER)
        if test "$use_gh" = true
            gh repo clone (basename $ENV_FOLDER) $ENV_FOLDER; or return
        else
            git clone https://github.com/nathanchance/(basename $ENV_FOLDER).git $ENV_FOLDER; or return
        end
    end
    git -C $ENV_FOLDER pull
    set hydro $GITHUB_FOLDER/hydro
    if not test -d $hydro
        mkdir -p (dirname $hydro)
        set -l clone_args -b personal
        if test "$use_gh" = true
            gh repo clone (basename $hydro) $hydro -- $clone_args
        else
            git clone $clone_args https://github.com/nathanchance/(basename $hydro).git $hydro; or return
        end
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
        if test "$LOCATION" != wsl
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
    if test "$trusted_gpg" = true
        decrypt_gpg_file botinfo
        decrypt_gpg_file muttrc
        decrypt_gpg_file muttrc.notifier
        decrypt_gpg_file config.ini $HOME/.config/tuxsuite/config.ini
    end

    # git repos and source folders
    switch $LOCATION
        case heztner-server
            mkdir -p $SRC_FOLDER

            set github_repos bug-files hugo-files nathanchance.github.io patches

            for linux_tree in linux linux-next linux-stable
                tmux new-window fish -c "cbl_setup_linux_repos $linux_tree; sleep 180"
            end

            tmux new-window fish -c "start_ssh_agent; and cbl_setup_other_repos; sleep 180"

        case wsl
            decrypt_gpg_file server_ip

            set github_repos hugo-files nathanchance.github.io

        case '*'
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
