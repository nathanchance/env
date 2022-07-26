#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_setup_linux_repos -d "Clone ClangBuiltLinux Linux repos into their proper places"
    for arg in $argv
        switch $arg
            case linux
                set pairs torvalds/linux:{$CBL_BLD_C,$CBL_BLD_P,$CBL_SRC}/$arg

            case linux-next
                set pairs next/linux-next:{{$CBL_BLD_C,$CBL_BLD_P,$CBL_SRC}/$arg,$CBL_BLD/rpi}

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
        if not test -f $cb
            wget -c -O $cb https://mirrors.kernel.org/pub/scm/.bundles/pub/scm/linux/kernel/git/$url/clone.bundle; or return
        end

        git clone $cb $folder

        git -C $folder remote remove origin
        git -C $folder remote add origin https://git.kernel.org/pub/scm/linux/kernel/git/$url.git
        git -C $folder remote update origin

        git -C $folder checkout master

        switch (basename $folder)
            case rpi
                git -C $folder config rerere.enabled true
                git -C $folder remote add -f --tags mainline https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
            case '*'
                git -C $folder branch --set-upstream-to=origin/master
                git -C $folder reset --hard origin/master
        end

        if string match -qr linux-stable $folder
            cbl_upd_stbl_wrktrs $folder
        end

        switch $folder
            case $CBL_SRC/linux $CBL_SRC/linux-next
                git -C $folder remote add -f korg git@gitolite.kernel.org:pub/scm/linux/kernel/git/nathan/linux
        end
    end
    rm -rf $tmp_dir

    # Set up Fedora source worktree
    set fedora $CBL_BLD/fedora
    if not test -d $fedora
        git -C $CBL_SRC/linux-next worktree add -B fedora --no-track $fedora origin/master
    end
end
