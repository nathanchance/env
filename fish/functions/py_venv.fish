#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function py_venv -d "Manage Python virtual environment"
    for arg in $argv
        switch $arg
            case c create e enter exit l ls list r rm remove x
                set -a actions $arg
            case '*'
                set venv $arg
        end
    end
    if not set -q actions
        print_error "no actions specified!"
        return 1
    end
    if not set -q venv; and not string match -qr '(l|ls|list)' $actions
        print_error "venv name not specified!"
        return 1
    end
    set venv_dir $MAIN_FOLDER/.venv
    set venv $venv_dir/$venv
    mkdir -p $venv_dir

    for action in $actions
        switch $action
            case c create
                python -m venv $venv

            case e enter
                if in_venv
                    print_error "Already in a virtual environment?"
                    return 1
                end

                set VIRTUAL_ENV_DISABLE_PROMPT 1
                set activate $venv/bin/activate.fish
                if not test -f $activate
                    print_error "$venv does not exist, run 'create'?"
                    return 1
                end
                source $activate

            case l ls list
                echo
                echo "Available virtual environments:"
                echo
                fd \
                    --base-directory $venv_dir \
                    --maxdepth 1 \
                    --type directory

            case r rm remove
                rm -fr $venv

            case x exit
                if not in_venv
                    print_error "Not in a virtual environment?"
                    return 1
                end
                deactivate
        end
    end
end
