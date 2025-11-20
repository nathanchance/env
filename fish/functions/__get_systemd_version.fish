#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function __get_systemd_version -d "Get current systemd version"
    if not command -q systemctl
        echo 0
        return 1
    end
    systemctl --version | string match "systemd*" | string replace -r "\D*(\d+)\D.*" '$1'
end
