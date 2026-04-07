#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function setup_libvirt -d "Setup libvirt for current user"
    __in_container_msg -h; or return

    if not command -q virsh
        request_root "Setting up libvirt"
        or return

        upd -y
        or return

        set distro (__get_distro)
        switch $distro
            case arch
                run0 pacman \
                    -S \
                    --noconfirm \
                    dmidecode \
                    dnsmasq \
                    libvirt \
                    qemu-desktop \
                    virt-install
                or return

            case fedora
                run0 dnf install -y @virtualization
                or return

            case '*'
                __print_error "$distro is not supported by setup_libvirt!"
                return 1
        end

        run0 fish -c "usermod -aG libvirt $USER
and systemctl enable --now libvirtd.service
and virsh net-autostart default
and if virsh net-info default | string match -qr 'Active:\s+no'
    virsh net-start default
end"
    end

    setup_libvirt_pool
end
