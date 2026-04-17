#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function virsh_get_dom_ip -d "Get IP address of libvirt domain"
    virsh domifaddr $argv[1] | string match -gr '([0-9.]+)/\d+$'
end
