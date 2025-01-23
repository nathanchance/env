#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function cbl_bld_tot_gcc -d "Build tip of tree GCC (often for comparison against clang)"
    set gcc_src $CBL_SRC_C/gcc
    if not test -d $gcc_src
        git clone https://gcc.gnu.org/git/gcc.git $gcc_src
        or return
    end

    set binutils_src $CBL_SRC_C/binutils
    if not test -d $binutils_src
        git clone https://sourceware.org/git/binutils-gdb.git $binutils_src
        python3 -c (string match -er '^LATEST_BINUTILS_RELEASE =' <$CBL_GIT/tc-build/build-binutils.py)"; print('binutils-' + '_'.join(str(x) for x in LATEST_BINUTILS_RELEASE if x))" | read binutils_tag
        git -C $binutils_src switch -d $binutils_tag
    end

    set date_time (date +%F_%H-%M-%S)
    set gcc_base_ver (cat $gcc_src/gcc/BASE-VER)
    set gcc_hash (git -C $gcc_src sha)
    set prefix $CBL_TC_GCC_STORE/$gcc_base_ver-$date_time-$gcc_hash

    set make_flags -j(nproc)

    set buildall $GITHUB_FOLDER/buildall
    if not test -d $buildall
        git clone https://github.com/nathanchance/buildall $buildall
        or return
    end

    pushd $buildall
    or return

    git cl

    make $make_flags
    or return

    for target in (PYTHONPATH=$PY_S python3 -c "from korg_tc import GCCManager; print('\n'.join(item for item in sorted(target for target in GCCManager.TARGETS if target not in ('arm64', 'loongarch', 'riscv'))))")
        set -l extra_conf
        switch $target
            case x86_64
                set extra_conf EXTRA_GCC_CONF=--disable-multilib
        end

        begin
            echo "BINUTILS_SRC=$binutils_src
CHECKING=release
ECHO=/bin/echo"
            if test -n "$extra_conf"
                echo $extra_conf
            end
            echo "GCC_SRC=$gcc_src
MAKEOPTS=$make_flags
PREFIX=$prefix"
        end >config
        cat config

        ./build --toolchain $target
        or return
    end
end
