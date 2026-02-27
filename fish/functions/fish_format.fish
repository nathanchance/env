#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function fish_format -d "Format all fish files in directory with fish_indent"
    rg -l '#!/usr/bin/(env )?fish' | while read -l file
        fish_indent -w $file
    end
end
