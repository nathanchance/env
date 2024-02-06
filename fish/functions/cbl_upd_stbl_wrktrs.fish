#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_upd_stbl_wrktrs -d "Update the worktrees for linux-stable"
    for folder in $argv
        if not test -d "$folder"
            header "Cloning $folder"
            clone_lnx_repo linux-stable $folder
        else
            header "Updating $folder"
            git -C $folder remote update
        end

        if test (dirname $folder) = $CBL_SRC
            set stable_versions $SUPPORTED_STABLE_VERSIONS
        else
            set stable_versions $CBL_STABLE_VERSIONS
        end

        for worktree in $folder-*
            set stable_version (string split -f 3 '-' (basename $worktree))
            if not contains $stable_version $stable_versions
                header "Removing $worktree"
                git -C $folder worktree remove --force $worktree
                git -C $folder bd linux-$stable_version.y
            end
        end

        for worktree in $folder-$stable_versions
            if not test -d $worktree
                header "Creating $worktree"
                set -l branch (stable_folder_to_branch $worktree)
                git -C $folder worktree add --track -b $branch $worktree origin/$branch
            end
        end
    end
end
