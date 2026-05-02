#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function virsh_reboot -d "Wrapper for 'virsh reboot'"
    for arg in $argv
        switch $arg
            case -a --all all
                for name in (__virsh_get_running_domains)
                    if not contains $name $names
                        set -a names $name
                    end
                end
            case '*'
                if not contains $arg $names
                    set -a names $arg
                end
        end
    end

    set ret 0
    for name in $names
        virsh reboot $name
        set ret (math $ret + $status)
    end
    return $ret
end
