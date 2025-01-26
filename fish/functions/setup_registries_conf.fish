#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function setup_registries_conf -d "Set up registries.conf for pull through ghcr.io cache"
    set registries_conf $HOME/.config/containers/registries.conf
    mkdir -p (path dirname $registries_conf); or return
    echo '[[registry]]
location="ghcr.io"
[[registry.mirror]]
location="192.168.4.207:5002"
insecure=true' >$registries_conf
end
