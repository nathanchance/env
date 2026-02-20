#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function user_setup -d "Setup a user account, downloading all files and placing them where they need to go"
    # Get arguments
    for arg in $argv
        switch $arg
            case -p --pull-thru-cache --pull-through-cache
                set pull_thru_cache true
        end
    end

    # If we are using GNOME Terminal, the "Unnamed" profile needs to be set
    if __is_installed gnome-terminal
        set gnome_prof_dir /org/gnome/terminal/legacy/profiles:/
        set gnome_prof_base :(dconf dump $gnome_prof_dir | string match -er "list=" | cut -d \' -f 2)
        if test "$gnome_prof_base" = ""
            set gnome_prof_base (dconf dump $gnome_prof_dir | head -1 | awk -F '[][]' '{print $2}')
            if test "$gnome_prof_base" = ""
                __print_error "Rename 'Unnamed' profile in GNOME Terminal before running this function"
                return 1
            end
        end
        set gnome_prof $gnome_prof_dir$gnome_prof_base/
    end

    # Set "trusted environment" variable to make decisions later
    switch $LOCATION
        case aadp chromebox framework-desktop honeycomb test-desktop-amd-8745HS test-desktop-intel-{11700,n100} test-laptop-intel
            set trusted_ssh true
        case hetzner workstation
            set trusted_gpg true
            set trusted_ssh true
    end
    if __in_orb
        set trusted_gpg true
        set trusted_ssh true
        set skip_install_ssh_keys true # orbstack passes along the macOS ssh-agent
    end
    set keys_folder /tmp/keys

    # Trusting an environment with GPG but not SSH makes little sense
    if test "$trusted_gpg" = true; and not test "$trusted_ssh" = true
        __print_error "This environment trusts GPG but not SSH?"
        return 1
    end

    # Set up SSH keys if requested
    if test "$trusted_ssh" = true
        # Set up gh
        if not gh auth status
            gh auth login; or return
            set first_time_gh true
        end
        set use_gh true

        set ssh_folder $HOME/.ssh
        if test "$skip_install_ssh_keys" != true; and not test -f $ssh_folder/id_ed25519
            mkdir -p $ssh_folder
            if not test -d $keys_folder
                gh repo clone keys $keys_folder; or return
            end

            set ssh_keys $keys_folder/ssh

            cp -v $ssh_keys/id_ed25519{,.pub} $ssh_folder
            chmod 600 $ssh_folder/id_ed25519

            if __is_location_primary
                cp -v $ssh_keys/korg-nathan $ssh_folder/id_korg
                chmod 600 $ssh_folder/id_korg

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
        end

        __connect_to_ssh_agent
        or return

        # Switch back to SSH protocol for GitHub CLI
        if test "$first_time_gh" = true
            gh config set -h github.com git_protocol ssh
            gh config set git_protocol ssh
            # This contains the credential helper configs; it will be properly recreated below
            rm -fr $HOME/.gitconfig
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

    rm -rf $keys_folder

    # Downloading/updating environment scripts
    if not test -d $ENV_FOLDER
        mkdir -p (path dirname $ENV_FOLDER)
        if test "$use_gh" = true
            gh repo clone (path basename $ENV_FOLDER) $ENV_FOLDER; or return
        else
            git clone https://github.com/nathanchance/(path basename $ENV_FOLDER).git $ENV_FOLDER; or return
        end
    end
    git -C $ENV_FOLDER pull

    # Download and update forked fisher plugins
    set forked_fisher_plugins \
        $GITHUB_FOLDER/hydro
    for forked_fisher_plugin in $forked_fisher_plugins
        if not test -d $forked_fisher_plugin
            mkdir -p (path dirname $forked_fisher_plugin)
            set -l clone_args -b personal
            if test "$use_gh" = true
                gh repo clone (path basename $forked_fisher_plugin) $forked_fisher_plugin -- $clone_args
            else
                git clone $clone_args https://github.com/nathanchance/(path basename $forked_fisher_plugin).git $forked_fisher_plugin; or return
            end
        end
        git -C $forked_fisher_plugin remote update
    end

    # Set up fish environment with fisher
    if fisher list &| string match -qr /tmp/env/fish
        fisher remove /tmp/env/fish
    end
    set fisher_plugins \
        $ENV_FOLDER/fish \
        $forked_fisher_plugins \
        PatrickF1/fzf.fish \
        jorgebucaran/autopair.fish \
        wfxr/forgit
    for fisher_plugin in $fisher_plugins
        fisher install $fisher_plugin; or return
    end

    # config.fish
    rm -rf $__fish_config_dir/config.fish
    ln -frsv $ENV_FOLDER/fish/config.fish $__fish_config_dir/config.fish

    # Invoke fish by default in bash
    # https://wiki.archlinux.org/title/Fish#Modify_.bashrc_to_drop_into_fish
    set bash_to_fish 'if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z $BASH_EXECUTION_STRING && $SHLVL == 1 ]]; then
    shopt -q login_shell && LOGIN_OPTION=\'--login\' || LOGIN_OPTION=\'\'
    exec fish $LOGIN_OPTION
fi'
    if test -f $HOME/.bashrc
        if string match -qr '\.bashrc\.d' <$HOME/.bashrc
            mkdir -p $HOME/.bashrc.d
            echo $bash_to_fish >$HOME/.bashrc.d/fish
        else if not string match -qr 'exec fish \$LOGIN_OPTION' <$HOME/.bashrc
            printf '\n%s\n' $bash_to_fish >$HOME/.bashrc
        end
    end

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
*.rej
rpmbuild/' >>$gitignore

    # Ensure podman registers with correct options for environment
    if command -q podman
        podman system info
        # If we have access to the NAS, use it for pulling ghcr.io images
        if test -d $NAS_FOLDER; or set -q pull_thru_cache
            setup_registries_conf; or return
        end
    end

    # Show Docker information if it is installed
    if command -q docker
        docker system info
    end

    # Set up libvirt storage pool
    if command -q virsh; and mountpoint -q /home
        set -l libvirt_pool $VM_FOLDER/libvirt

        mkdir -p $libvirt_pool
        if __user_exists libvirt-qemu
            setfacl -m u:libvirt-qemu:rx $HOME
        end

        virsh pool-define-as --name default --type dir --target $libvirt_pool
        virsh pool-autostart default
        virsh pool-start default
    end

    # Binaries
    if __is_location_primary
        clone_aur_repos
    end
    if command -q modprobed-db
        modprobed-db
        modprobed-db store
        systemctl --user enable --now modprobed-db.service
    end
    if test (__get_distro) = alpine
        upd fisher vim; or return
    else
        updall --no-os; or return
    end

    # Git config and aliases
    git_setup

    # Configuration files (vim, tmux, etc)
    set configs $ENV_FOLDER/configs
    ln -fnrsv $configs/tmux/.tmux.conf.common $HOME/.tmux.conf.common
    ln -fnrsv $configs/tmux/.tmux.conf.container $HOME/.tmux.conf.container
    if test "$LOCATION" = vm
        ln -fnrsv $configs/tmux/.tmux.conf.vm $HOME/.tmux.conf
    else
        ln -fnrsv $configs/tmux/.tmux.conf.regular $HOME/.tmux.conf
    end
    mkdir -p $HOME/.config/tio
    ln -frsv $configs/local/tio.config $HOME/.config/tio/config
    vim_setup

    # Terminal profiles
    if set -q DISPLAY
        if __is_installed gnome-terminal
            dconf load $gnome_prof <$configs/local/Nathan.dconf
        end

        if __is_installed google-chrome
            echo "--enable-features=WebUIDarkMode
--force-dark-mode" >$HOME/.config/chrome-flags.conf
        end

        if __is_installed konsole
            set konsole_share $HOME/.local/share/konsole
            mkdir -p $konsole_share
            ln -frsv $configs/local/Nathan.profile $konsole_share/Nathan.profile
            ln -frsv $configs/local/snazzy.colorscheme $konsole_share/snazzy.colorscheme
        end

        if __is_installed xfce4-terminal
            set xfce_share $HOME/.local/share/xfce4/terminal/colorschemes
            mkdir -p $xfce_share
            ln -frsv $configs/local/snazzy.theme $xfce_share
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
        case hetzner workstation
            mkdir -p $SRC_FOLDER

            set github_repos \
                actions-playground \
                actions-workflows \
                arch-repo \
                bug-files \
                buildall \
                hugo-files \
                local_manifests \
                nathanchance.github.io \
                patches

            for linux_tree in linux linux-next linux-stable
                tmux new-window fish -c "cbl_setup_linux_repos $linux_tree; or exec fish -l"
            end

            tmux new-window fish -c "begin; __connect_to_ssh_agent; and cbl_setup_other_repos; end; or exec fish -l"
    end

    if set -q github_repos
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

    # Setup systemd-nspawn
    setup_sd_nspawn
end
