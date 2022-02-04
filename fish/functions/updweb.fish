#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function updweb -d "Update my website with hugo"
    set website $GITHUB_FOLDER/nathanchance.github.io
    if not test -d $website
        mkdir -p (dirname $website)
        gh repo clone (basename $website) $website
    end

    set hugo_files $GITHUB_FOLDER/hugo-files
    if not test -d $hugo_files
        mkdir -p (dirname $hugo_files)
        gh repo clone (basename $hugo_files) $hugo_files
    end

    for arg in $argv
        switch $arg
            case -p --push
                set push true
        end
    end

    fd -E CNAME . $website -x rm -rfv
    hugo -d $website -s $hugo_files

    set url (git -C $hugo_files remote get-url origin | sed -e 's/git@github.com:/https:\/\/github.com\//' -e 's/.git$//')
    set hash (git -C $hugo_files show -s --format=%H)

    git -C $website aa
    git -C $website ac -m "website: Update to $url/commit/$hash"
    if test "$push" = true
        git -C $website push
    end
    return 0
end
