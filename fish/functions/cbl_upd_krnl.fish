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

    switch $LOCATION
        case vm
            set location vm-(uname -m)
        case '*'
            set location $LOCATION
    end

    switch $location
        case aadp honeycomb vm-aarch64
            __in_container_msg -h; or return
            test (__get_distro) = fedora; or return

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
            ssh $remote_user@$remote_host cat $krnl_bld/b2sum | string match -rq '^(?<remote_krnl_rpm_sha>[0-9a-f]+)\s+(?<remote_krnl_rpm>.*)$'
            set base_krnl_rpm (path basename $remote_krnl_rpm)
            # If we have the kernel we are planning to download already, no need to redownload
            set cached_krnl_rpm $NAS_FOLDER/Kernels/rpm/$base_krnl_rpm
            if test -e $cached_krnl_rpm; and test (b2sum $cached_krnl_rpm | string split -f 1 ' ') = "$remote_krnl_rpm_sha"
                set krnl_rpm $cached_krnl_rpm

                __print_green "INFO: Installing cached kernel from $krnl_rpm"
            else
                __print_warning "$base_krnl_rpm is not cached, downloading..."

                scp $remote_user@$remote_host:$remote_krnl_rpm /tmp
                or return

                set krnl_rpm /tmp/$base_krnl_rpm
            end

            sudo dnf install -y $krnl_rpm
            or return

            if test "$reboot" = true
                sudo reboot
            end

        case chromebox test-desktop-amd-8745HS test-desktop-intel-{11700,n100} test-laptop-intel vm-x86_64
            __in_container_msg -h
            or return

            for arg in $argv
                switch $arg
                    case -k --kexec -r --reboot
                        set -a install_args $arg
                        set reboot true
                    case $VALID_ARCH_KRNLS
                        set krnl linux-(string replace 'linux-' '' $arg)
                end
            end
            if not set -q krnl
                __print_error "Kernel is required!"
                return 1
            end

            # Cache sudo/doas permissions
            if test "$reboot" = true
                sudo true; or return
            end

            # Download kernel
            set remote_krnl_bld (tbf $krnl | string replace $TMP_BUILD_FOLDER $remote_tmp_build_folder)
            ssh $remote_user@$remote_host cat $remote_krnl_bld/b2sum | string match -rq '^(?<remote_krnl_pkg_sha>[0-9a-f]+)\s+(?<remote_krnl_pkg>.*)$'
            set base_krnl_pkg (path basename $remote_krnl_pkg)
            set cached_krnl_pkg $NAS_FOLDER/Kernels/pkg/$base_krnl_pkg
            if test -e $cached_krnl_pkg; and test (b2sum $cached_krnl_pkg | string split -f 1 ' ') = "$remote_krnl_pkg_sha"
                set krnl_pkg $cached_krnl_pkg

                __print_green "INFO: Installing cached kernel from $krnl_pkg"
            else
                __print_warning "$base_krnl_pkg is not cached, downloading..."

                scp $remote_user@$remote_host:$remote_krnl_pkg /tmp
                or return

                set krnl_pkg /tmp/$base_krnl_pkg
            end

            # Install kernel and reboot as asked
            install_arch_kernel $install_args $krnl $krnl_pkg

        case hetzner workstation
            for arg in $argv
                switch $arg
                    case -k --kexec -r --reboot
                        set -a install_args $arg
                    case -p --plain
                        set plain true
                    case $VALID_ARCH_KRNLS
                        set krnl linux-(string replace 'linux-' '' $arg)
                    case '*'
                        set -a bld_krnl_pkg_args $arg
                end
            end
            if not set -q krnl
                __print_error "Kernel is required!"
                return 1
            end

            if test "$plain" != true
                set -a bld_krnl_pkg_args \
                    --cfi \
                    --lto
            end
            set -a bld_krnl_pkg_args $krnl

            if __in_container
                cbl_bld_krnl_pkg $bld_krnl_pkg_args
                return
            else
                sd_nspawn -r "cbl_bld_krnl_pkg $bld_krnl_pkg_args"
                or return
            end

            install_arch_kernel $install_args $krnl
    end
end
