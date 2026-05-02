#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function __virsh_get_running_domains -d "Get all running libvirt domains"
    virsh list --name --state-running | string match -rv '^$'
end
