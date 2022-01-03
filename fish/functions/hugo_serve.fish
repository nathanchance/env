#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function hugo_serve -d "Runs 'hugo server' based on WSL's IP address"
    set ip (dirname (ip addr | grep eth0 | grep inet | awk '{print $2}'))
    hugo server --baseUrl=$ip --bind=0.0.0.0 $argv
end
