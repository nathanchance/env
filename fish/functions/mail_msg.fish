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
        for file in $argv
            if test -f $file
                set -a inputs $file
            else
                print_error "Input file '$file' does not exist!"
                return 1
            end
        end
    else
        set tmp_file (mktemp)
        cat /dev/stdin >$tmp_file
        set inputs $tmp_file
    end

    set -l date (date +%F-%T)

    mutt -F $muttrc -s "$hostname: $date" -a $inputs -- nathan@kernel.org <$inputs[1]
    if set -q tmp_file
        rm -f $tmp_file
    end
end
