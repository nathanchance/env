#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

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

        if test -d $folder
            continue
        end

        set bundle_dir $NAS_FOLDER/kernel.org/bundles/latest
        if test -d $bundle_dir
            set cb_dir $bundle_dir
        else
            set cb_dir $tmp_dir
        end
        switch $url
            case stable/linux
                set suffix linux-stable
            case '*'
                set suffix (basename $url)
        end
        set cb $cb_dir/clone.bundle-$suffix

        mkdir -p (dirname $folder)
        if not test -f $cb
            wget -c -O $cb https://mirrors.kernel.org/pub/scm/.bundles/pub/scm/linux/kernel/git/$url/clone.bundle; or return
        end

        clone_from_bundle $cb $folder https://git.kernel.org/pub/scm/linux/kernel/git/$url.git master; or return

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
