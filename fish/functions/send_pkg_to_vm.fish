#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function send_pkg_to_vm -d "Send package source files to virtual machine"
    set ssh_port 8022 # from cbl_vmm
    if not lsof -i :$ssh_port &>/dev/null
        __print_error "QEMU does not appear to be running?"
        return 1
    end

    if not set distro (ssh_vm cat /etc/os-release &| string match -gr '^ID=(.*)')
        __print_error "Could not get running distribution name?"
        return 1
    end

    set package $argv[1]
    if test -z "$package"
        read -P 'Package to build: ' package
    end

    switch $distro
        case arch
            set package_dirs $ENV_FOLDER/pkgbuilds/$package $SRC_FOLDER/packaging/pkg/$package
        case fedora
            set package_dirs $ENV_FOLDER/specs/$package $SRC_FOLDER/packaging/rpm/$package
        case '*'
            __print_error "Unable to handle finding package files for $distro?"
            return 1
    end
    for item in $package_dirs
        if test -d $item
            set src_dir $item
        end
    end
    if not set -q src_dir
        __print_error "Could not find source for package '$package' in possible locations '$package_dirs'!"
        return 1
    end

    set dst_dir /tmp/$package
    if test -e $src_dir/.git
        ssh_vm rm -fr $dst_dir
        ssh_vm mkdir -p $dst_dir
        echo "Copying $src_dir to $dst_dir via 'git archive'..."
        git -C $src_dir archive --format=tar HEAD | ssh_vm tar -C $dst_dir -vxf -
    else
        ssh_vm rm -fr $dst_dir
        set ssh_cmd \
            ssh -p $ssh_port

        if not string match -qr "^\[localhost\]:$port" <$HOME/.ssh/known_hosts
            set -a ssh_cmd \
                -o "StrictHostKeyChecking no"
        end
        rsync --progress --recursive --rsh "$ssh_cmd" $src_dir nathan@localhost:(path dirname $dst_dir)
    end
end
