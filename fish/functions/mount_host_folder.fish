#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function mount_host_folder -d "Mount host folder in virtual machine"
    sudo fish -c "
    if not test -d $HOST_FOLDER
        mkdir $HOST_FOLDER; or return
        chown -R $USER:$USER $HOST_FOLDER; or return
    end
    if not mountpoint -q $HOST_FOLDER
        mount -t virtiofs host $HOST_FOLDER; or return
    end"
end
