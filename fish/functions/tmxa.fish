#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function tmxa -d "Attach to a tmux session if it exists, start a new one if not"
    if test -z "$TMUX"
        switch $LOCATION
            case aadp honeycomb pi test-{desktop-intel,desktop-amd,laptop-intel}
                set tmuxp_cfg test
            case generic workstation
                set tmuxp_cfg $LOCATION
        end
        if set -q tmuxp_cfg
            tmuxp load --yes $tmuxp_cfg
        else
            tmux new-session -AD -s main
        end
    end
end
