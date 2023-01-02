#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function mail_msg -d "Send myself an email"
    if is_github_actions
        set muttrc $GITHUB_WORKSPACE/muttrc.notifier
    else
        set muttrc $HOME/.muttrc.notifier
    end
    if not test -f $muttrc
        print_error "$muttrc does not exist!"
        return 1
    end

    if test (count $argv) -gt 0
        set file $argv[1]
        if test -f $file
            set input $file
        else
            print_error "$file does not exist!"
            return 1
        end
    else
        set tmp_file (mktemp)
        cat /dev/stdin >$tmp_file
        set input $tmp_file
    end

    set -l date (date +%F-%T)

    mutt -a $input -F $muttrc -s "$hostname: $date" <$input -- nathan@kernel.org
    if set -q tmp_file
        rm -f $tmp_file
    end
end
