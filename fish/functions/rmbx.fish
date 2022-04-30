#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function rmbx -d "Read an mbox directory created by lei"
    for arg in $argv
        switch $arg
            case -u --update
                set update true
            case '*'
                set mbx $MAIL_FOLDER/$arg
        end
    end

    if not test -d $mbx
        print_error "$mbx does not exist!"
        return 1
    end

    if test "$update" = true
        lei up $mbx; or return
    end

    mutt -f $mbx
end
