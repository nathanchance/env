#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_setup_other_repos -d "Download other ClangBuiltLinux repos"
    for repo in boot-utils continuous-integration2:ci tc-build qemu-binaries
        if string match -q -r ":" $repo
            set folder (string split -f2 ":" $repo)
            set repo (string split -f1 ":" $repo)
        else
            set folder $repo
        end

        set folder $CBL_GIT/$repo
        if not test -d $folder
            mkdir -p (dirname $folder)
            git clone git@github.com:ClangBuiltLinux/$repo.git $folder
        end
        git -C $folder fork
        git -C $folder remote update
    end

    set llvm_mirror $CBL_MIRRORS/llvm
    if not test -d $llvm_mirror
        mkdir -p (dirname $llvm_mirror)
        git clone https://github.com/llvm/llvm-project $llvm_mirror
        git -C $llvm_mirror remote add github git@github.com:ClangBuiltLinux/llvm-project.git
    end

    for repo in creduce-files llvm-kernel-testing tc-build
        set folder $CBL/$repo
        if not test -d $folder
            mkdir -p (dirname $folder)
            switch $repo
                case tc-build
                    set clone_args -b personal
            end
            git clone $clone_args git@github.com:nathanchance/$repo.git $folder
        end
    end

    set pi_scripts $CBL_BLD/pi-scripts
    if not test -d $pi_scripts
        mkdir -p (dirname $pi_scripts)
        git clone git@github.com:nathanchance/pi-scripts $pi_scripts
    end

    cbl_clone_repo wsl2

    set korg_nathan $CBL_SRC/korg-linux
    if not test -d $korg_nathan
        mkdir -p (dirname $korg_nathan)
        git clone git@gitolite.kernel.org:pub/scm/linux/kernel/git/nathan/linux $korg_nathan
        git -C $korg_nathan remote add -f --tags linus https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/
        git -C $korg_nathan remote add -f --tags next https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/
    end
end
