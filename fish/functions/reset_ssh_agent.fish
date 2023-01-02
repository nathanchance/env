#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function reset_ssh_agent -d "Reset the ssh-agent"
    rm -fr /tmp/ssh-*
    rm -fr $HOME/.ssh/.ssh-agent.fish
    killall ssh-agent
end
