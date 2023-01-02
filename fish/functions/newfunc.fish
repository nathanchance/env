#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function newfunc -d "Generate and edit new function fish"
    for func_name in $argv
        set func_file $ENV_FOLDER/fish/functions/$func_name.fish

        if test -f $func_file
            print_error "$func_name already exists!"
            return 1
        end

        echo "#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) "(date +%Y)" Nathan Chancellor

function $func_name
end" >$func_file
        edfunc $func_file
    end
end
