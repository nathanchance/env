#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function virsh_ssh -d "ssh into libvirt domain"
    set domain $argv[1]
    set cmd_to_run $argv[2..]

    ssh root@(virsh_get_dom_ip $domain) $cmd_to_run
end
