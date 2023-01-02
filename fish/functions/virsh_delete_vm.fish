#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function virsh_delete_vm -d "Remove virtual machine using virsh"
    set name $argv[1]

    if set virsh_dominfo (virsh dominfo $name 2>/dev/null)
        if string match -qr "State:\s+running" $virsh_dominfo
            virsh destroy $name
        end

        virsh undefine --nvram $name
        or virsh undefine $name
        or return

        virsh vol-delete --pool default $name.qcow2
    end
end
