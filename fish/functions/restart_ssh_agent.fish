#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function restart_ssh_agent -d "Reset then start the ssh-agent"
    reset_ssh_agent
    start_ssh_agent
end
