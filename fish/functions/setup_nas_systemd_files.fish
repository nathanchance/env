#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function setup_nas_systemd_files -d "Install systemd files for mounting NAS to a machine"
    # Couple of initial checks
    in_container_msg -h; or return
    if not command -q mount.nfs
        print_error "mount.nfs could not be found, install it!"
        return 1
    end

    sudo fish -c "cp -v $ENV_FOLDER/configs/systemd/mnt-nas.{auto,}mount /etc/systemd/system
and chmod 644 /etc/systemd/system/mnt-nas.{auto,}mount
and systemctl enable --now mnt-nas.automount"
end
