#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_upd_src -d "Update source trees in $CBL_SRC"
    for arg in $argv
        switch $arg
            case c clean d dev p patched
                set -a types (string sub -l 1 $arg)
            case l llvm m mainline n next s stable
                set -a trees (string sub -l 1 $arg)
            case sync
                set sync true
        end
    end
    if not set -q types
        set types c d p
    end
    if not set -q trees
        set trees l m n s
    end

    for value in $types
        if test "$value" = c # clean
            for tree in $trees
                switch $tree
                    case l
                        set base llvm-project
                    case m
                        set base linux
                    case n
                        set base linux-next
                    case s
                        set base linux-stable
                end

                set folder $CBL_SRC_C/$base

                if test "$base" = linux-stable
                    cbl_upd_stbl_wrktrs $folder

                    for wrktr in $folder-$CBL_STABLE_VERSIONS
                        git -C $wrktr reset --hard @{u}
                        or return
                    end
                else
                    # Header here because cbl_upd_stbl_wrktrs displays it
                    header "Updating $folder"

                    if not test -d $folder
                        clone_repo_from_bundle (path basename $folder) $folder
                    end

                    git -C $folder urh
                    or return
                end
            end

        else if test "$value" = d # development
            for tree in $trees
                set -l remotes origin

                switch $tree
                    case l
                        set base llvm-project
                    case m
                        set base linux
                    case n
                        set base linux-next
                    case s
                        set base linux-stable
                end

                set folder $CBL_SRC_D/$base

                header "Updating $folder"

                if test -d $folder
                    if git -C $folder remote &| string match -qr origin-ssh
                        set -a remotes origin-ssh
                    end
                    git -C $folder remote update $remotes
                else
                    if test "$base" = linux-stable
                        cbl_upd_stbl_wrktrs $folder
                    else
                        clone_repo_from_bundle (path basename $folder) $folder
                    end
                end
                or return
            end

        else if test "$value" = p # patched
            set -l folders

            for tree in $trees
                switch $tree
                    case m
                        set -a folders $CBL_SRC_P/linux
                    case n
                        # Ignore updating -next if sync is set
                        if not set -q sync
                            set -a folders $CBL_SRC_P/linux-next
                        end
                    case s
                        set -a folders $CBL_SRC_P/linux-stable-$CBL_STABLE_VERSIONS
                end
            end

            for folder in $folders
                header "Updating $folder"

                if test -d $folder
                    set git \
                        git -C $folder

                    if is_tree_dirty $folder
                        $git stash
                        set pop true
                    else
                        set -e pop
                    end

                    switch $folder
                        # These trees never rebase so we can just 'pull -r'
                        case '*'/linux '*'/linux-stable'*'
                            $git pull -r

                        case '*'/linux-next
                            set prior_upstream ($git sha @{u})

                            $git remote update --prune
                            or return

                            set current_upstream ($git sha @{u})

                            if test $prior_upstream != $current_upstream; or not $git merge-base --is-ancestor $current_upstream HEAD
                                $git rebase --interactive --onto $current_upstream $prior_upstream ($git bn)
                            end
                    end
                    or return

                    if string match -qr linux-stable $folder
                        cbl_ptchmn -C $folder -s
                    end

                    if set -q pop
                        $git stash pop
                    end
                else
                    if string match -qr linux-stable $folder
                        cbl_upd_stbl_wrktrs $CBL_SRC_P/linux-stable
                    else
                        clone_repo_from_bundle (path basename $folder) $folder
                    end

                    cbl_ptchmn -C $folder -a
                end
            end

        else
            print_error "Unhandled value: $value!"
            return 1

        end
    end
end
