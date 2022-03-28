#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function btop -d "Runs btop depending on where it is available"
    if command -q btop
        command btop $argv
    else if test -x $BIN_FOLDER/btop/bin/btop
        $BIN_FOLDER/btop/bin/btop $argv
    else
        print_error "btop could not be found. Run 'upd btop' to install it."
        return 1
    end
end
