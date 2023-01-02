#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function kgmbx -d "Fetch an mbox file from lore.kernel.org using b4 and open it in mutt"
    set msg_id $argv[1]
    set mbox (mktemp --suffix=.mbox)

    if b4 mbox -n $mbox $msg_id
        mutt -f $mbox
        rm $mbox
    end
end
