#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function install_rpi_kernel -d "Install Raspberry Pi kernel from a tarball"
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
                set reboot true
            case '*'.tar.zst
                set krnl_pkg (realpath $arg)
        end
    end

    if not set -q arch
        print_error "\$arch must be set (arm or arm64)"
        return 1
    end
    if not set -q krnl_pkg
        print_error "\$krnl_pkg must be set"
        return 1
    end
    if not set -q ver
        print_error "\$ver must be set"
        return 1
    end

    # Installation folder
    set prefix /boot/custom-$ver-$arch

    # Temporary work folder
    set workdir (mktemp -d)
    pushd $workdir; or return

    # Extract .tar.zst
    tar -atf $krnl_pkg | string match -qr '^lib/'
    if test $pipestatus[2] -ne 0
        set -a tar_args --strip-components=1
    end
    tar $tar_args -axvf $krnl_pkg; or return

    # Move modules into their place
    set mod_dir lib/modules/*
    rm $mod_dir/{build,source}
    sudo rm -frv /lib/modules/(basename $mod_dir)
    sudo mv -v $mod_dir /lib/modules; or return

    # Install image and dtbs
    sudo rm -fr $prefix
    switch $arch
        case arm
            set dtbs boot/dtbs/*/bcm2{71,83}*

            sudo install -Dvm755 boot/vmlinux-kbuild-* $prefix/zImage; or return
        case arm64
            set dtbs boot/dtbs/*/broadcom/bcm2{7,8}*

            zcat boot/vmlinuz-* | sudo install -Dvm755 /dev/stdin $prefix/Image; or return
    end
    for dtb in $dtbs
        sudo install -Dvm755 $dtb $prefix/(basename $dtb); or return
    end

    # Copy cmdline.txt because we are modifying os_prefix
    set cmdline $prefix/cmdline.txt
    sudo cp -v /boot/cmdline.txt $cmdline; or return

    # Ensure that there is always a serial console option
    if grep -q console= $cmdline
        sudo sed -i s/serial0/ttyS1/ $cmdline
    else
        printf "console=ttyS1,115200 %s\n" (cat $cmdline) | sudo tee $cmdline
    end

    # Remove "quiet" and "splash" from cmdline
    sudo sed -i 's/quiet splash //' $cmdline

    if test "$reboot" = true
        sudo systemctl reboot
    else
        popd
        rm -fr $workdir
    end
end
