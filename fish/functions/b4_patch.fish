#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function b4_patch -d "Download a b4 .mbx and rename the extension to .patch"
    for arg in $argv
        switch $arg
            case '*@*'
                set -a msg_ids $arg
            case '*'
                set -a b4_args $arg
        end
    end

    for msg_id in $msg_ids
        b4 am -l -P _ $b4_args $msg_id
    end

    for patch in *.mbx
        mv -v $patch (string replace .mbx .patch $patch)
    end
end
