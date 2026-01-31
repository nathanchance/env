#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function clean_old_kernels -d "Clean up old installed kernels"
    set distro (__get_distro)
    switch $distro
        case almalinux fedora rocky
            set -l kernels (rpm -q kernel{,-{core,modules}} | string match -rv (uname -r | string replace -a - _) | string replace -a .(uname -m) "" | fzf -m)
            if test -n "$kernels"
                run0 dnf remove -y $kernels
            end
        case '*'
            __print_error "No support for '$distro'!"
            return 1
    end
end
