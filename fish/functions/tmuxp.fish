#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function tmuxp -d "Runs tmuxp depending on how it is available"
    if command -q tmuxp
        command tmuxp $argv
    else
        set tmuxp_prefix $BIN_FOLDER/tmuxp
        set tmuxp_bin $tmuxp_prefix/bin/tmuxp

        if test -x $tmuxp_bin
            PYTHONPATH=$tmuxp_prefix $tmuxp_bin $argv
        else
            print_error "tmuxp could not be found. Run 'upd tmuxp' to install it."
            return 1
        end
    end
end
