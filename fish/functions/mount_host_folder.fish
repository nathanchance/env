#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function mount_host_folder -d "Mount host folder in virtual machine"
    sudo fish -c "
    if not test -d $HOST_FOLDER
        mkdir $HOST_FOLDER
        and chown -R $USER:$USER $HOST_FOLDER
    end
    or return

    if mountpoint -q $HOST_FOLDER
        umount $HOST_FOLDER
    end
    mount -t virtiofs host $HOST_FOLDER"
end
