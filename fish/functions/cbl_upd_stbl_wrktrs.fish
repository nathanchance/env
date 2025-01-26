#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_upd_stbl_wrktrs -d "Update the worktrees for linux-stable"
    for folder in $argv
        if not test -d "$folder"
            header "Cloning $folder"
            clone_repo_from_bundle linux-stable $folder
        else
            header "Updating $folder"
            git -C $folder remote update origin
        end

        set dirname (path dirname $folder)
        if test $dirname = $CBL_SRC_D
            set stable_versions $SUPPORTED_STABLE_VERSIONS
        else
            set stable_versions $CBL_STABLE_VERSIONS
        end

        for worktree in $folder-*
            set basename (path basename $worktree)
            set stable_version (string split -f 3 '-' $basename)
            if not contains $stable_version $stable_versions
                header "Removing $worktree"
                # Non-temporal git worktrees need to use the host path, as the
                # have been converted to the host path below.
                git -C $folder worktree remove --force (nspawn_path -H $worktree)
                git -C $folder bd linux-$stable_version.y

                if test $dirname = $CBL_SRC_P
                    set patches_repo $GITHUB_FOLDER/patches
                    set patches_folder $patches_repo/$basename

                    if test -d $patches_folder
                        rm -r $patches_folder
                        and git -C $patches_repo add $patches_folder
                        and git -C $patches_repo c -m "patches: Remove $basename due to EOL"
                    end
                    or return
                end
            end
        end

        for worktree in $folder-$stable_versions
            if not test -d $worktree
                header "Creating $worktree"
                set -l branch (stable_folder_to_branch $worktree)
                git -C $folder worktree add --track -b $branch $worktree origin/$branch
            end
        end

        # We need to ensure the git worktree links are valid for both
        # host and systemd-nspawn
        fix_wrktrs_for_nspawn $folder
    end
end
