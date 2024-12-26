#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_upd_krnl -d "Update machine's kernel"
    if not set -q remote_user
        set remote_user nathan
    end
    if not set -q remote_host
        set remote_host $MAIN_REMOTE_IP
    end
    if not set -q remote_main_folder
        set remote_main_folder /home/$remote_user
    end
    if not set -q remote_tmp_build_folder
        set remote_tmp_build_folder /mnt/nvme/tmp/build
    end

    set valid_arch_krnls {linux-,}{debug,{mainline,next}-llvm}

    switch $LOCATION
        case pi
            # Pi 4 can run either Raspbian or Fedora, be more specific to allow the situation to change
            if test (uname -m) = aarch64
                set location pi4
            else
                set location pi3
            end
        case vm
            set location vm-(uname -m)
        case '*'
            set location $LOCATION
    end

    switch $location
        case aadp honeycomb pi4 vm-aarch64
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
            set -q krnl_bld; or set krnl_bld (tbf fedora | string replace $TMP_BUILD_FOLDER $remote_tmp_build_folder)
            set remote_rpm_folder (string replace $MAIN_FOLDER $remote_main_folder $krnl_bld)/rpmbuild/RPMS/aarch64
            set krnl_rpm (ssh $remote_user@$remote_host fd -e rpm -u 'kernel-[0-9]+' $remote_rpm_folder)
            scp $remote_user@$remote_host:$krnl_rpm /tmp; or return

            sudo dnf install -y /tmp/(basename $krnl_rpm); or return

            if test "$reboot" = true
                sudo reboot
            end

        case hetzner workstation
            for arg in $argv
                switch $arg
                    case -k --kexec -r --reboot
                        set -a install_args $arg
                    case $valid_arch_krnls
                        set krnl linux-(string replace 'linux-' '' $arg)
                    case '*'
                        set -a bld_krnl_pkg_args $arg
                end
            end
            if not set -q krnl
                print_error "Kernel is required!"
                return 1
            end

            set -a bld_krnl_pkg_args \
                --cfi \
                --lto \
                $krnl

            if in_container
                cbl_bld_krnl_pkg $bld_krnl_pkg_args
            else
                dbxe dev-arch -- $PYTHON_SCRIPTS_FOLDER/cbl_bld_krnl_pkg.py $bld_krnl_pkg_args
                or return

                install_arch_kernel $install_args $krnl
            end

        case pi3
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
            set out (tbf rpi | string replace $TMP_BUILD_FOLDER $remote_tmp_build_folder)/$arch
            scp $remote_user@$remote_host:$out/linux-'*'-$arch.tar.zst /tmp

            # Install kernel
            install_rpi_kernel $arch $ver $install_args /tmp/linux-*-$arch.tar.zst

        case test-desktop-amd test-desktop-intel-{11700,n100} test-laptop-intel vm-x86_64
            in_container_msg -h
            or return

            for arg in $argv
                switch $arg
                    case -k --kexec -r --reboot
                        set -a install_args $arg
                        set reboot true
                    case $valid_arch_krnls
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

            # Download kernel
            set remote_krnl_bld (tbf $krnl | string replace $TMP_BUILD_FOLDER $remote_tmp_build_folder)
            if ssh $remote_user@$remote_host "test -d $remote_krnl_bld/pkgbuild"
                set subdir pkgbuild/
            end
            scp $remote_user@$remote_host:$remote_krnl_bld/"$subdir"$krnl-'*'.tar.zst /tmp
            or return

            # Install kernel and reboot as asked
            install_arch_kernel $install_args $krnl
    end
end
