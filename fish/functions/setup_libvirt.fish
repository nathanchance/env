#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function setup_libvirt -d "Setup libvirt for current user"
    in_container_msg -h; or return

    # Cache sudo permissions
    sudo true; or return

    if not command -q virsh
        upd -y; or return

        set distro (get_distro)
        switch $distro
            case arch
                sudo pacman \
                    -S \
                    --noconfirm \
                    dmidecode \
                    dnsmasq \
                    libvirt \
                    qemu-desktop \
                    virt-install; or return

                sudo pacman \
                    -S \
                    --noconfirm \
                    --ask 4 \
                    iptables-nft; or return

            case fedora
                sudo dnf install -y @virtualization; or return

            case '*'
                print_error "$distro is not supported by setup_libvirt!"
                return 1
        end
    end

    # Ensure that the rest of this function says in sync with setup_libvirt_common() in 'bash/common'
    set user (id -un)
    sudo fish -c "usermod -aG libvirt $user
and systemctl enable --now libvirtd.service
and virsh net-autostart default
and if virsh net-info default | grep -q 'Active:.*no'
    virsh net-start default
end"
end
