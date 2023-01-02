#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function virsh_ips -d "Shorthand for 'virsh net-dhcp-leases default'"
    virsh net-dhcp-leases default
end
