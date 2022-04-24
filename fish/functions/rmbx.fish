#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function rmbx -d "Read an mbox directory created by lei"
    for arg in $argv
        switch $arg
            case -u --update
                set update true
            case '*'
                set mbx /mail/$arg
        end
    end

    set mail_root (dirname $MAIL_FOLDER)
    if not test -d $mail_root$mbx
        print_error "$mail_root$mbx does not exist!"
        return 1
    end

    if test "$update" = true
        lei up $mbx; or return
    end

    mutt -f $mail_root$mbx
end
