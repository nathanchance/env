#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function __virsh_get_all_domains -d "Get all libvirt domains"
    virsh list --all --name | string match -rv '^$'
end
