#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function upd -d "Runs the update command for the current distro"
    switch (get_distro)
        case arch
            yay
        case debian ubuntu
            sudo sh -c 'apt update && apt upgrade && apt autoremove -y'
    end
end
