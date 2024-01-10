#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function newpywrapper -d "Generate Python wrapper fish function"
    for func_name in $argv
        set func_file $ENV_FOLDER/fish/functions/$func_name.fish
        set python_file $PYTHON_SCRIPTS_FOLDER/$func_name.py
        set escaped_file (string replace $PYTHON_SCRIPTS_FOLDER '$PYTHON_SCRIPTS_FOLDER' $python_file)

        if not test -f $python_file
            print_error "$python_file does not exist?"
            return 1
        end

        if test -f $func_file
            print_error "$func_name already exists!"
            return 1
        end

        echo "#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) "(date +%Y)" Nathan Chancellor

function $func_name -d \"Wrapper for $(basename $python_file)\"
    $escaped_file \$argv
end" >$func_file
        echo "Generated $func_file"
    end
end
