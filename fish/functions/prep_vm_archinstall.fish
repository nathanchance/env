#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function prep_vm_archinstall -d "Prepare archinstall files for virtual machine installation"
    read -P 'Password for virtual machine user: ' -s user_pass

    ssh_vm root copy-id
    or return

    set creds /tmp/creds.json
    echo '{
    "!root-password": null,
    "!users": [
        {
            "!password": "'$user_pass'",
            "sudo": true,
            "username": "nathan"
        }
    ]
}' >$creds

    ssh_vm root transfer $ENV_FOLDER/configs/archinstall/vm_config.json :/root/config.json
    ssh_vm root transfer $creds :/root/(path basename $creds)

    rm -f $creds
end
