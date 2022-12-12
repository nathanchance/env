#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function gen_slim_initrd -d "Generate a slim initial ramdisk within a virtual machine"
    in_container_msg -h; or return

    if test (count $argv) -eq 0
        set prefix /tmp
    else
        set prefix $argv[1]
    end

    switch (get_distro)
        case alpine
            set src /boot/initramfs-virt
        case debian
            set src (realpath /boot/initrd.img)
    end
    if set -q src
        if not test -e $src
            print_error "src ('$src') could not be found?"
            exit 1
        end
        set dst $prefix/(basename $src)
    else
        set dst $prefix/initramfs.img
    end

    if not test -f $dst
        if command -q dracut
            sudo fish -c "dracut --no-kernel $dst && chown $USER:$USER $dst"
        else if set -q src
            pushd (mktemp -d)
            begin
                sudo gzip -c -d $src | cpio -i
                and rm -fr etc/modprobe.d lib/modules usr/lib/modprobe.d usr/lib/modules
                and find . | cpio -o -H newc | gzip -c >$dst
                and rm -fr $PWD
                and popd
            end; or return
        else
            print_error "No suitable way to generate initrd found?"
            exit 1
        end
    end

    echo "Initial ramdisk is available at: $dst"
end
