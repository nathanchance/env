#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_upd_src_c -d "Update $CBL_SRC_C to the latest versions"
    set targets $argv
    if test -z "$targets"
        set targets mainline stable
    end

    for target in $targets
        switch $target
            case m mainline
                set folder $CBL_SRC_C/linux

                if not test -d $folder
                    clone_lnx_repo (basename $folder) $folder
                end

                git -C $folder pull
                or return

            case n next
                set folder $CBL_SRC_C/linux-next

                if not test -d $folder
                    clone_lnx_repo (basename $folder) $folder
                end

                git -C $folder urh
                or return

            case s stable
                set folder $CBL_SRC_C/linux-stable

                cbl_upd_stbl_wrktrs $folder

                for folder in $CBL_SRC_C/linux-stable-$CBL_STABLE_VERSIONS
                    git -C $folder reset --hard @{u}
                end
        end
    end
end
