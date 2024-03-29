#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_upd_src_p -d "Update $CBL_SRC_P to the latest versions"
    set targets $argv
    if test -z "$targets"
        set targets next mainline stable
    end

    for target in $targets
        switch $target
            case m mainline
                set -a folders $CBL_SRC_P/linux
            case n next
                set -a folders $CBL_SRC_P/linux-next
            case s stable
                set -a folders $CBL_SRC_P/linux-stable-$CBL_STABLE_VERSIONS
        end
    end

    for folder in $folders
        header "Updating $folder"

        if test -d $folder
            if is_tree_dirty $folder
                git -C $folder stash
                set pop true
            else
                set -e pop
            end

            switch $folder
                case '*'/linux '*'/linux-stable'*'
                    git -C $folder pull -r
                case '*'/linux-next
                    git -C $folder urbi
            end

            if string match -qr linux-stable $folder
                cbl_ptchmn -C $folder -s
            end

            if set -q pop
                git -C $folder stash pop
            end
        else
            if string match -qr linux-stable $folder
                cbl_upd_stbl_wrktrs $CBL_SRC_P/linux-stable
            else
                clone_repo_from_bundle (basename $folder) $folder
            end

            cbl_ptchmn -C $folder -a
        end
    end
end
