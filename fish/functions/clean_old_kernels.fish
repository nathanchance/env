#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function clean_old_kernels -d "Clean up old installed kernels"
    set distro (get_distro)
    switch $distro
        case fedora
            set -l kernels (rpm -q kernel{,-{core,modules}} | fzf -m | sed "s;.$(uname -m);;g")
            if test -n "$kernels"
                sudo dnf remove -y $kernels
            end
        case '*'
            print_error "No support for '$distro'!"
            return 1
    end
end
