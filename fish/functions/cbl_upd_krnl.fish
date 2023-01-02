#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_upd_krnl -d "Update machine's kernel"
    set remote_user nathan
    set remote_host 192.168.4.188
    set remote_main_folder /home/$remote_user

    switch $LOCATION
        case vm
            set location vm-(uname -m)
        case '*'
            set location $LOCATION
    end

    switch $location
        case hetzner-server workstation
            cbl_upd_krnl_pkg $argv

        case honeycomb vm-aarch64
            in_container_msg -h; or return
            test (get_distro) = fedora; or return

            for arg in $argv
                switch $arg
                    case '*/*'
                        set krnl_bld $arg
                    case -r --reboot
                        set reboot true
                end
            end

            # Cache sudo/doas permissions
            sudo true; or return

            # Download .rpm package
            set -q krnl_bld; or set krnl_bld $CBL_BLD/fedora
            set remote_rpm_folder (string replace $MAIN_FOLDER $remote_main_folder $krnl_bld)/rpmbuild/RPMS/aarch64
            set krnl_rpm (ssh $remote_user@$remote_host fd -e rpm 'kernel-[0-9]+' $remote_rpm_folder)
            scp $remote_user@$remote_host:$krnl_rpm /tmp; or return

            sudo dnf install -y /tmp/(basename $krnl_rpm); or return

            if test "$reboot" = true
                sudo reboot
            end

        case pi
            in_container_msg -h; or return

            # Cache sudo/doas permissions
            sudo true; or return

            for arg in $argv
                switch $arg
                    case arm arm64
                        set arch $arg
                    case 'mainline*' 'next*'
                        set ver $arg
                    case -r --reboot
                        set -a install_args $arg
                end
            end
            if not set -q arch
                print_error "\$arch must be set (arm or arm64)"
                return 1
            end
            if not set -q ver
                print_error "\$ver must be set"
                return 1
            end

            # Grab .tar.zst package
            set remote_build (string replace $MAIN_FOLDER $remote_main_folder $CBL_BLD)
            set out $remote_build/rpi/.build/$arch
            scp $remote_user@$remote_host:$out/linux-'*'-$arch.tar.zst /tmp

            # Install kernel
            install_rpi_kernel $arch $ver $install_args /tmp/linux-*-$arch.tar.zst

        case test-desktop-amd test-desktop-intel test-laptop-intel vm-x86_64
            in_container_msg -h; or return

            for arg in $argv
                switch $arg
                    case -r --reboot
                        set reboot true
                    case '*'
                        set krnl linux-(string replace 'linux-' '' $arg)
                end
            end
            if not set -q krnl
                print_error "Kernel is required!"
                return 1
            end

            # Cache sudo/doas permissions
            if test "$reboot" = true
                sudo true; or return
            end

            cd /tmp; or return

            scp $remote_user@$remote_host:(string replace $MAIN_FOLDER $remote_main_folder $ENV_FOLDER)/pkgbuilds/$krnl/'*'.tar.zst .; or return

            sudo pacman -U --noconfirm *$krnl*.tar.zst

            if test "$reboot" = true
                if test -d /sys/firmware/efi
                    set boot_conf /boot/loader/entries/$krnl.conf
                    if test -f $boot_conf
                        sudo bootctl set-oneshot $krnl.conf; or return
                    else
                        print_error "$boot_conf does not exist!"
                        return 1
                    end
                end
                sudo reboot
            end

        case wsl
            in_container_msg -h; or return

            set i 1
            while test $i -le (count $argv)
                switch $argv[$i]
                    case -g --github
                        set kernel_location github
                    case -k --kernel-suffix
                        set next (math $i + 1)
                        set kernel_suffix $argv[$next]
                        set i $next
                    case -l --local
                        set kernel_location local
                    case -s --server
                        set kernel_location server
                end
                set i (math $i + 1)
            end
            if test -z "$kernel_location"
                set kernel_location github
            end

            set kernel /mnt/c/Users/natec/Linux/kernel"$kernel_suffix"
            rm -r $kernel

            switch $kernel_location
                case local
                    cp -v $CBL_BLD/wsl2/arch/x86/boot/bzImage $kernel
                case github
                    set repo nathanchance/WSL2-Linux-Kernel
                    crl -o $kernel https://github.com/$repo/releases/download/(glr $repo)/bzImage
                case server
                    set src (string replace $MAIN_FOLDER $remote_main_folder $CBL_BLD)/wsl2
                    set image arch/x86/boot/bzImage
                    scp $remote_user@$remote_host:$src/$image $kernel
            end
    end
end
