#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_upd_software_symlinks -d "Update symlinks to a stow or QEMU folder"
    if test (count $argv) -lt 1
        print_error "This function requires the sofware as the first argument!"
        return 1
    end

    set pkg $argv[1]
    switch $pkg
        case binutils llvm
            set stow_dir $CBL_TC_STOW

            # source handling
            if test (count $argv) -eq 2
                set src $argv[2]
            else
                switch $pkg
                    case binutils
                        set src_stow $CBL_TC_STOW_BNTL
                        set binary as
                    case llvm
                        set src_stow $CBL_TC_STOW_LLVM
                        set binary clang
                end

                set src_version (fd -d 1 -t d . $src_stow -x basename | sort -r | fzf --preview="$src_stow/{}/bin/$binary --version")
                if test -z "$src_version"
                    return 0
                end

                set src $src_stow/$src_version
            end

            # destination handling
            switch $pkg
                case binutils
                    set dest (dirname $CBL_TC_BNTL)
                case llvm
                    set dest (dirname $CBL_TC_LLVM)
            end

            set stow_pkg (basename $dest)

        case qemu
            if test (count $argv) -eq 2
                set src $argv[2]
            else
                set src_version (fd -d 1 -t d . $CBL_QEMU_INSTALL -x basename | sort -r | fzf --preview="$CBL_QEMU_INSTALL/{}/bin/qemu-system-x86_64 --version")
                if test -z "$src_version"
                    return 0
                end

                set src $CBL_QEMU_INSTALL/$src_version
            end

            rm -fr $CBL_QEMU_BIN; or return
            mkdir -p $CBL_QEMU_BIN; or return
            for arch in arm aarch64 i386 m68k mips mipsel ppc ppc64 riscv64 s390x x86_64
                ln -frsv $src/bin/qemu-system-$arch $CBL_QEMU_BIN; or return
            end
            ln -frsv $src/bin/qemu-img $CBL_QEMU_BIN; or return

            return 0
    end

    ln -fnrsv $src $dest; or return
    stow -d $stow_dir -R $stow_pkg
end
