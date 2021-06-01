#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function gmbx -d "Fetch an mbox file from lore.kernel.org using b4 and open it in mutt"
    if command -q b4
        set msg_id $argv[1]
        set mbox (mktemp --suffix=.mbox)

        set fish_trace 1

        if b4 mbox -n $mbox $msg_id
            mutt -f $mbox
            rm $mbox
        end
    end
end
