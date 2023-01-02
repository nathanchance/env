#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cts -d "Create temporary script"
    if test (count $argv) -gt 0
        set tmpdir $argv
    else
        cbl_clone_repo repro-scripts
        set tmpdir $CBL_REPRO
    end

    set -g tmp (mktemp --suffix=.fish --tmpdir=$tmpdir); or return
    chmod +x $tmp
    printf '#!/usr/bin/env fish\n\n\n' >$tmp
    vim '+normal G$' +startinsert $tmp
end
