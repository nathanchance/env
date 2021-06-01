#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function upd_kernel -d "Update machine's kernel"
    set fish_trace 1

    switch $LOCATION
        case generic workstation
            pushd $ENV_FOLDER/pkgbuilds/linux-mainline-llvm; or return

            # Prerequisite: Clean up old kernels
            rm -- *.tar.zst

            # Generate localmodconfig
            gen_localmodconfig

            # Build the kernel
            makepkg -C; or return

            set -e fish_trace
            echo Run
            printf '\n\t$ yay -U %s\n\n' (readlink -f -- *.tar.zst | perl -pe 's/\n/ /')
            echo "to install new kernel"

            popd

        case pi
            for arg in $argv
                switch $arg
                    case arm arm64
                        set arch $arg
                    case 'mainline*' 'next*'
                        set ver $arg
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

            set tmp_boot (mktemp -d)
            set main_boot /boot/custom-$ver-$arch

            mkdir -p $tmp_boot/modules

            switch $arch
                case arm
                    set dtbs /
                    set kernel zImage
                case arm64
                    set dtbs /broadcom/
                    set kernel Image
            end

            set user nathan
            set remote_build (string replace pi $user $CBL_BLD | string replace /mnt/ssd /home/$user $remote_build)
            set out $remote_build/rpi/build/$arch
            set rootfs $out/rootfs

            rsync -v $user@$SERVER_IP:$rootfs$dtbs'*'.dtb $tmp_boot; or return
            rsync -rv $user@$SERVER_IP:$rootfs/lib/modules/'*' $tmp_boot/modules; or return
            rsync -v $user@$SERVER_IP:$out/arch/$arch/boot/$kernel $tmp_boot; or return

            set mod_dir (fd -d 1 . $tmp_boot/modules)
            if test -z "$mod_dir"
                print_error "Could not find modules in at $tmp_boot/modules"
                return 1
            end

            # Move modules
            sudo rm -frv /lib/modules/(basename $mod_dir)
            sudo mv -v $mod_dir /lib/modules
            sudo rmdir -v $tmp_boot/modules

            # Move all other files
            sudo rm -frv $main_boot
            sudo mv -v $tmp_boot $main_boot

            # Copy cmdline.txt because we are modifying os_prefix
            sudo cp -v /boot/cmdline.txt $main_boot

            # Ensure that there is always a serial console option
            set cmdline $main_boot/cmdline.txt
            if grep -q console= $cmdline
                sudo sed -i s/serial0/ttyS1/ $cmdline
            else
                printf "console=ttyS1,115200 %s\n" (cat $cmdline) | sudo tee $cmdline
            end

            # Remove "quiet" and "splash" from cmdline
            sudo sed -i 's/quiet splash //' $cmdline

        case wsl
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
                    cp -v $CBL_BLD/wsl2/build/x86_64/arch/x86/boot/bzImage $kernel
                case github
                    set repo nathanchance/WSL2-Linux-Kernel
                    crl -o $kernel https://github.com/$repo/releases/download/(glr $repo)/bzImage
                case server
                    set src $CBL_BLD/wsl2
                    set out build/x86_64
                    set image arch/x86/boot/bzImage
                    scp nathan@$SERVER_IP:$src/$out/$image $kernel
            end
    end
end
