#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cltmp -d "Cleans /tmp and ~/tmp except for ssh, systemd, and tmux files"
    fd -t f -E '*.fish' . /tmp -x rm
    fd -t d -d 1 -E 'tmux*' -E 'ssh-*' -E 'systemd*' . /tmp -x rm -r
    rm -rf $TMP_FOLDER
    mkdir -p $TMP_FOLDER
end
