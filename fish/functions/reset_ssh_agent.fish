#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function reset_ssh_agent -d "Reset the ssh-agent"
    rm -frv $HOME/.ssh/.ssh-agent.{fish,sock}
    killall -v ssh-agent
end
