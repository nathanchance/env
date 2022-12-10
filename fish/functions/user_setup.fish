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
        case hetzner-server workstation wsl
            set trusted_gpg true
            set trusted_ssh true
        case honeycomb pi test-desktop-amd test-desktop-intel test-laptop-intel
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
            set first_time_gh true
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
  ServerAliveInterval 60

Host sos.*.platformequinix.com
  HostkeyAlgorithms +ssh-rsa
  PubkeyAcceptedAlgorithms +ssh-rsa' >>$ssh_folder/config
        end

        if test -f $HOME/.ssh/.ssh-agent.fish
            start_ssh_agent; or return
        else
            if not ssh-add -l
                ssh-add $HOME/.ssh/id_ed25519; or return
            end
        end

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

    if test "$LOCATION" != wsl
        rm -rf $keys_folder
    end

    # Downloading/updating environment scripts
    if not test -d $ENV_FOLDER
        mkdir -p (dirname $ENV_FOLDER)
        if test "$use_gh" = true
            gh repo clone (basename $ENV_FOLDER) $ENV_FOLDER; or return
        else
            git clone https://github.com/nathanchance/(basename $ENV_FOLDER).git $ENV_FOLDER; or return
        end
    end
    git -C $ENV_FOLDER pull

    # Download and update forked fisher plugins
    set forked_fisher_plugins \
        $GITHUB_FOLDER/forgit \
        $GITHUB_FOLDER/hydro
    for forked_fisher_plugin in $forked_fisher_plugins
        if not test -d $forked_fisher_plugin
            mkdir -p (dirname $forked_fisher_plugin)
            set -l clone_args -b personal
            if test "$use_gh" = true
                gh repo clone (basename $forked_fisher_plugin) $forked_fisher_plugin -- $clone_args
            else
                git clone $clone_args https://github.com/nathanchance/(basename $forked_fisher_plugin).git $forked_fisher_plugin; or return
            end
        end
        git -C $forked_fisher_plugin remote update
    end

    # Set up fish environment with fisher
    if fisher list &| grep -q /tmp/env/fish
        fisher remove /tmp/env/fish
    end
    set fisher_plugins \
        $ENV_FOLDER/fish \
        $forked_fisher_plugins \
        PatrickF1/fzf.fish \
        jorgebucaran/autopair.fish
    if not command -q zoxide
        set -a fisher_plugins jethrokuan/z
    end
    for fisher_plugin in $fisher_plugins
        fisher install $fisher_plugin; or return
    end

    # config.fish
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
*.rej
rpmbuild/' >>$gitignore

    # Ensure podman registers with correct options for environment
    if command -q podman
        # Use SSD for container storage on Raspberry Pi
        if test "$LOCATION" = pi; and test "$MAIN_FOLDER" != "$HOME"
            upd_strg_cfg
        end
        podman system info
    end

    # Show Docker information if it is installed
    if command -q docker
        docker system info
    end

    # Set up libvirt storage pool
    if command -q virsh; and mountpoint -q /home
        set -l libvirt_pool $VM_FOLDER/libvirt

        mkdir -p $libvirt_pool
        if user_exists libvirt-qemu
            setfacl -m u:libvirt-qemu:rx $HOME
        end

        virsh pool-define-as --name default --type dir --target $libvirt_pool
        virsh pool-autostart default
        virsh pool-start default
    end

    # Binaries
    if is_location_primary
        clone_aur_repos
    end
    if command -q modprobed-db
        modprobed-db
        modprobed-db store
        systemctl --user enable --now modprobed-db.service
    end
    if test (get_distro) = alpine
        upd fisher vim; or return
    else
        updall --no-os; or return
    end
    if has_container_manager; and test "$LOCATION" != wsl
        dbxc --yes
    end

    # Git config and aliases
    git_setup

    # Configuration files (vim, tmux, etc)
    set configs $ENV_FOLDER/configs
    ln -fsv $configs/tmux/.tmux.conf $HOME/.tmux.conf
    vim_setup

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
        case heztner-server workstation
            mkdir -p $SRC_FOLDER

            set github_repos arch-repo bug-files hugo-files nathanchance.github.io patches

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
