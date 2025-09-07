#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function __gen_slim_initrd -d "Generate a slim initial ramdisk within a virtual machine"
    __in_container_msg -h; or return

    if test (count $argv) -eq 0
        set prefix /tmp
    else
        set prefix $argv[1]
    end

    switch (__get_distro)
        case alpine
            set src /boot/initramfs-virt
        case debian
            set src (realpath /boot/initrd.img)
    end
    if set -q src; and not test -e $src
        __print_error "src ('$src') could not be found?"
        exit 1
    end
    set dst $prefix/initramfs

    if not test -f $dst
        if command -q dracut
            sudo fish -c "dracut --no-kernel $dst && chown $USER:$USER $dst"
        else if command -q mkinitcpio
            sudo fish -c "mkinitcpio -g $dst -k none && chown $USER:$USER $dst"
        else if set -q src
            pushd (mktemp -d)
            begin
                set comp_prog (sudo python3 -c "from pathlib import Path
initrd_bytes = Path('$src').read_bytes()
if initrd_bytes.startswith(b'\x28\xb5\x2f\xfd'):
    print('zstd')
elif initrd_bytes.startswith(b'\x1f\x8b'):
    print('gzip')
else:
    print('initrd_bytes_unhandled')")
                sudo $comp_prog -c -d $src | cpio -i
                and rm -fr etc/modprobe.d lib/modules usr/lib/modprobe.d usr/lib/modules
                and find . | cpio -o -H newc | gzip -c >$dst
                and rm -fr $PWD
                and popd
            end; or return
        else
            __print_error "No suitable way to generate initrd found?"
            return 1
        end
    end

    echo "Initial ramdisk is available at: $dst"
end
