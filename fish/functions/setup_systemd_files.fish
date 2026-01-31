#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function setup_systemd_files -d "Set up various systemd files"
    set targets $argv
    # user implicitly depends on env
    if contains user $targets; and not contains env $targets
        set -a targets env
    end
    # nas must be run on the host and have mount.nfs installed
    if contains nas $targets
        __in_container_msg -h
        or return

        if not command -q mount.nfs
            __print_error "mount.nfs could not be found, install it!"
            return 1
        end
    end
    set systemd_configs $ENV_FOLDER/configs/systemd

    for target in $targets
        switch $target
            case env
                set env_file $HOME/.config/environment.d/50-personal-env.conf
                mkdir -p (path dirname $env_file)

                for var in CBL_SRC_M NAS_FOLDER PYTHON_SCRIPTS_FOLDER
                    printf "%s=%s\n" $var (nspawn_path -H $$var)
                end >$env_file

            case nas
                run0 fish -c "cp -v $systemd_configs/mnt-nas.{auto,}mount /etc/systemd/system
and chmod 644 /etc/systemd/system/mnt-nas.{auto,}mount
and systemctl enable --now mnt-nas.automount"

            case user
                set user_cfg_dir $HOME/.config/systemd/user
                set user_files \
                    nas-bundles.{service,timer}

                mkdir -p $user_cfg_dir
                for user_file in $systemd_configs/$user_files
                    ln -fnrsv $user_file $user_cfg_dir
                    or return
                end
        end
    end
end
