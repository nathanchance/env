#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_linux_repos -d "Clone ClangBuiltLinux Linux repos into their proper places"
    for arg in $argv
        switch $arg
            case linux
                set pairs torvalds/linux:{$CBL_BLD_C,$CBL_BLD_P,$CBL_MIRRORS,$CBL_SRC}/$arg

            case linux-next
                set pairs next/linux-next:{{$CBL_BLD_C,$CBL_BLD_P,$CBL_SRC}/$arg,$CBL_BLD/rpi,$CBL_SRC/linux-cfi}

            case linux-stable
                set pairs stable/linux:{$CBL_BLD_C,$CBL_BLD_P,$CBL_SRC}/$arg
        end
    end

    set tmp_dir (mktemp -d)
    for pair in $pairs
        set url (string split -f1 ":" $pair)
        set folder (string split -f2 ":" $pair)

        switch $url
            case next/linux-next
                set suffix next
            case stable/linux
                set suffix stable
            case torvalds/linux
                set suffix mainline
        end
        set cb $tmp_dir/clone.bundle-$suffix

        if test -d $folder
            continue
        end

        mkdir -p (dirname $folder)
        if not test -d $cb
            wget -c -O $cb https://mirrors.kernel.org/pub/scm/.bundles/pub/scm/linux/kernel/git/$url/clone.bundle; or return
        end

        git clone $cb $folder

        git -C $folder remote remove origin
        git -C $folder remote add origin https://git.kernel.org/pub/scm/linux/kernel/git/$url.git
        git -C $folder remote update origin

        git -C $folder checkout master

        if test (basename $folder) = rpi; or test (basename $folder) = linux-cfi
            git -C $folder config rerere.enabled true
            git -C $folder remote add -f --tags mainline https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
            git -C $folder remote add -f --tags sami https://github.com/samitolvanen/linux.git
        else
            git -C $folder branch --set-upstream-to=origin/master
            git -C $folder reset --hard origin/master
        end

        if string match -q -r linux-stable $folder
            upd_stbl_wrktrs $folder
        end

        if string match -q -r mirrors $folder
            git -C $folder remote add github git@github.com:ClangBuiltLinux/linux.git
        end
    end
    rm -rf $tmp_dir
end
