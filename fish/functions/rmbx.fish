#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

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
        __print_error "$mbx does not exist!"
        return 1
    end

    if test "$update" = true
        lei up $mbx; or return
    end

    mutt -f $mbx
    set ret $status
    if test $ret -eq 130
        return 0
    end
    return $ret
end
