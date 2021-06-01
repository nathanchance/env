#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bldgcc -d "Builds the latest GCC suitable for building the Linux kernel"
    if test -z "$BINUTILS"
        set BINUTILS 2.36.1
    end
    if test -z "$GCC"
        set GCC 11.1.0
    end

    if test (count $argv) -eq 0
        print_error "blgcc needs the targets to build as arguments"
        return 1
    end

    set bld_opts --toolchain
    for arg in $argv
        switch $arg
            case --binutils --gcc --toolchain
                set bld_opts $arg
            case all
                set targets arm arm64 m68k mips mipsel powerpc powerpc64 powerpc64le riscv64 s390x x86_64
            case '*'
                set -a targets $arg
        end
    end

    set bld $GCC_TC_FOLDER/build
    if not test -d $bld
        mkdir -p (dirname $bld)
        git clone https://github.com/nathanchance/buildall $bld
    end

    set gcc_src $bld/gcc-$GCC
    if not test -d $gcc_src
        crl https://mirrors.kernel.org/gnu/gcc/(basename $gcc_src)/(basename $gcc_src).tar.xz | tar -C (dirname $gcc_src) -xJf -
    end

    set binutils_src $bld/binutils-$BINUTILS
    if not test -d $binutils_src
        crl https://mirrors.kernel.org/gnu/binutils/(basename $binutils_src).tar.xz | tar -C (dirname $binutils_src) -xJf -
    end

    if not test -x $bld/timert
        make -C $bld -j(nproc)
    end

    if test -z "$PREFIX"
        set PREFIX $GCC_TC_FOLDER/$GCC
    end

    echo "BINUTILS_SRC=$binutils_src
CHECKING=release
ECHO=/bin/echo
GCC_SRC=$gcc_src
MAKEOPTS=-j"(nproc)"
PREFIX=$PREFIX" >$bld/config

    # Build a /mnt/c free PATH because bldall does not handle this well
    set --path bldgcc_path
    for val in $PATH
        if not string match -q -r /mnt/c/ $val
            set -a bldgcc_path $val
        end
    end

    for target in $targets
        rm -rf $bld/$target
        PATH="$bldgcc_path" $bld/build $bld_opts $target
    end
end
