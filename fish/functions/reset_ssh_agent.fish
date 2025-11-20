#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function reset_ssh_agent -d "Reset the ssh-agent"
    if __in_nspawn; and not test -L $HOME/.ssh/.container-ssh-agent.fish
        rm -frv $HOME/.ssh/.container-ssh-agent.{fish,sock}
    else
        rm -frv $HOME/.ssh/.host-ssh-agent.{fish,sock}
    end
    set -e SSH_AUTH_SOCK
    killall -v ssh-agent
end
