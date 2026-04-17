#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function virsh_delete_vm -d "Remove virtual machine using virsh"
    set running_domains (virsh list --name --state-running | string match -rv '^$')

    for domain in $argv
        if contains $domain $running_domains
            virsh destroy $domain
            or return
        end

        set -l nvram
        if virsh dumpxml $domain | string match -qr nvram
            set nvram --nvram
        end

        virsh undefine $nvram --remove-all-storage $domain
        or return
    end
end
