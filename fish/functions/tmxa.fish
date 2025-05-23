#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function tmxa -d "Attach to a tmux session if it exists, start a new one if not"
    if test -z "$TMUX"
        switch $LOCATION
            case aadp honeycomb pi test-{desktop-intel-{11700,n100},desktop-amd-{4300G,8745HS},laptop-intel}
                set tmuxp_cfg test
            case generic
                if in_orb
                    set tmuxp_cfg primary
                else
                    set tmuxp_cfg generic
                end
            case hetzner workstation
                set tmuxp_cfg primary
        end
        if set -q tmuxp_cfg
            tmuxp load --yes $tmuxp_cfg
        else
            tmux new-session -AD -s main
        end
    end
end
