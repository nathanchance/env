#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_setup_linux_repos -d "Clone ClangBuiltLinux Linux repos into their proper places"
    for arg in $argv
        switch $arg
            case linux
                set pairs torvalds/linux:{$CBL_SRC_C,$CBL_SRC_D,$CBL_SRC_P}/$arg

            case linux-next
                set pairs next/linux-next:{$CBL_SRC_C,$CBL_SRC_D,$CBL_SRC_P}/$arg

            case linux-stable
                set pairs stable/linux:{$CBL_SRC_C,$CBL_SRC_D,$CBL_SRC_P}/$arg
        end
    end

    set tmp_dir (mktemp -d)
    for pair in $pairs
        set url (string split -f1 ":" $pair)

        set folder (string split -f2 ":" $pair)
        if test -d $folder
            continue
        end

        set bundle $NAS_FOLDER/bundles/$arg.bundle
        if test -e $bundle
            # Will be handled by clone_repo_from_bundle
            set -e bundle
        else
            switch $url
                case stable/linux
                    set suffix linux-stable
                case '*'
                    set suffix (basename $url)
            end
            set bundle $tmp_dir/clone.bundle-$suffix

            wget -c -O $bundle https://mirrors.kernel.org/pub/scm/.bundles/pub/scm/linux/kernel/git/$url/clone.bundle
        end

        clone_repo_from_bundle (basename $folder) $folder $bundle
        or return

        if string match -qr linux-stable $folder
            cbl_upd_stbl_wrktrs $folder
        end

        switch $folder
            case $CBL_SRC_D/linux $CBL_SRC_D/linux-next
                git -C $folder remote add -f korg git@gitolite.kernel.org:pub/scm/linux/kernel/git/nathan/linux
        end
    end
    rm -rf $tmp_dir

    # Set up Fedora and Raspberry Pi source worktrees
    for worktree in $CBL_BLD/{fedora,rpi}
        if not test -d $worktree
            git -C $CBL_SRC_D/linux-next worktree add -B (basename $worktree) --no-track $worktree
            or return
        end
    end
end
