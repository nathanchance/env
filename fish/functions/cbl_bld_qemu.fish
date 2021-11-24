#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_bld_qemu -d "Build QEMU for use with ClangBuiltLinux"
    for arg in $argv
        switch $arg
            case -u --update
                set update true
        end
    end

    if test -n "$VERSION"
        set qemu_src $CBL_QEMU_SRC/qemu-$VERSION
        mkdir -p (dirname $qemu_src)
        crl https://download.qemu.org/(basename $qemu_src).tar.xz | tar -C (dirname $qemu_src) -xJf -
        set qemu_ver $VERSION
    else
        set qemu_src $CBL_QEMU_SRC/qemu
        if not test -d $qemu_src
            mkdir -p (dirname $qemu_src)
            git clone -j(nproc) --recurse-submodules https://gitlab.com/qemu-project/qemu.git $qemu_src
        end

        git -C $qemu_src clean -dfqx
        git -C $qemu_src submodule foreach --recursive git clean -dfqx

        if test "$update" = true
            git -C $qemu_src reset --hard
            git -C $qemu_src submodule foreach git reset --hard
            git -C $qemu_src pull --rebase
            git -C $qemu_src submodule update --recursive
        end

        set qemu_ver (git -C $qemu_src sh -s --format=%H)
    end

    if test -z "$PREFIX"
        set PREFIX $CBL_QEMU_INSTALL/(date +%F-%H-%M-%S)-$qemu_ver
    end

    if not test -x $PREFIX/bin/qemu-system-x86_64
        set qemu_bld $qemu_src/build
        rm -rf $qemu_bld
        mkdir -p $qemu_bld
        pushd $qemu_bld; or return

        podcmd -s $qemu_src/configure --prefix=$PREFIX; or return
        podcmd -s make -skj(nproc) install; or return
        popd
    end

    rm -rf $CBL_QEMU_BIN
    mkdir -p $CBL_QEMU_BIN
    for arch in arm aarch64 i386 m68k mips mipsel ppc ppc64 riscv64 s390x x86_64
        ln -frsv $PREFIX/bin/qemu-system-$arch $CBL_QEMU_BIN
    end
    ln -frsv $PREFIX/bin/qemu-img $CBL_QEMU_BIN
end
