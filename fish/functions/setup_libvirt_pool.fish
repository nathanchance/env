#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function setup_libvirt_pool -d "Set up default libvirt storage pool in $VM_FOLDER"
    __in_container_msg -h
    or return

    if not command -q virsh
        __print_warning "libvirt not installed, skipping..."
        return
    end

    set libvirt_pool $VM_FOLDER/libvirt
    if test -e $libvirt_pool
        __print_warning "$libvirt_pool already exists, skipping..."
        return
    end

    mkdir -p $libvirt_pool
    if __user_exists libvirt-qemu
        set libvirt_user libvirt-qemu
    else if __user_exists qemu
        set libvirt_user qemu
    end
    if set -q libvirt_user
        setfacl -m u:$libvirt_user:rx $HOME
    end

    virsh pool-define-as --name default --type dir --target $libvirt_pool
    virsh pool-autostart default
    virsh pool-start default
end
