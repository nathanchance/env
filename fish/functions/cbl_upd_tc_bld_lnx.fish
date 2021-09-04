#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_upd_tc_bld_lnx -d "Update the version of Linux built for PGO in tc-build"
    for arg in $argv
        switch $arg
            case -p --personal
                set mode personal
            case -r --release
                set mode release
        end
    end

    if not set -q mode
        set mode personal
    end

    set linux $CBL_SRC/linux
    pushd $linux; or return
    git ru
    set kver (git describe --abbrev=0 origin/master | sed 's/v//')

    switch $mode
        case personal
            set bprefix pgo
            set kernel $CBL/tc-build/kernel
            set tar_ext gz
            set url https://git.kernel.org/torvalds/t
        case release
            set bprefix v$kver-pgo
            set kernel $CBL_GIT/tc-build/kernel
            set tar_ext xz
            set url https://cdn.kernel.org/pub/linux/kernel/v5.x
    end

    rm -r $kernel/linux*

    for config in defconfig allyesconfig
        git checkout $bprefix-$config; or continue
        switch $config
            case defconfig
                git rebase v$kver
            case allyesconfig
                git rebase $bprefix-defconfig
        end
        git format-patch --stdout v$kver..$bprefix-$config >$kernel/linux-$kver-$config.patch
    end

    set tarball linux-$kver.tar.$tar_ext
    cd $kernel; or return

    gen_sha256sum $url/$tarball

    sed -i "s/LINUX=.*/LINUX=linux-$kver/" $kernel/build.sh

    popd
end
