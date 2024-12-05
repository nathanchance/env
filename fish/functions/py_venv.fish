#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function py_venv -d "Manage Python virtual environment"
    for arg in $argv
        switch $arg
            case c create e enter exit i in install l ls list r rm remove u up update x
                set -a actions $arg
            case python'*'
                set python $arg
            case '*'
                set venv $arg
        end
    end
    if not set -q actions
        print_error "no actions specified!"
        return 1
    end
    if not set -q python
        set python python3
    end
    if not set -q venv
        if in_venv
            set venv (basename $VIRTUAL_ENV)
        else
            switch $arg
                case c create e enter r rm remove
                    print_error "venv name not specified!"
                    return 1
            end
        end
    end
    switch $venv
        case continuous-integration2
            set packages \
                (cat $CBL_GIT/continuous-integration2/requirements.txt) \
                pylint \
                ruff \
                yapf
        case kernel-dev
            set packages $SRC_FOLDER/b4
        case main
            set packages \
                pylint \
                requests \
                ruff \
                vulture \
                yapf
    end
    set venv_dir $MAIN_FOLDER/.venv
    set venv $venv_dir/$venv
    mkdir -p $venv_dir

    for action in $actions
        switch $action
            case c create
                $python -m venv $venv

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

            case i in install
                switch (basename $venv)
                    case continuous-integration2 kernel-dev main
                        if contains $SRC_FOLDER/b4 $packages
                            if not test -d $SRC_FOLDER/b4
                                mkdir -p $SRC_FOLDER
                                and git clone https://git.kernel.org/pub/scm/utils/b4/b4.git/ $SRC_FOLDER/b4
                            end
                            or return

                            git -C $SRC_FOLDER/b4 urh
                            or return
                        end
                        pip install --upgrade pip $packages
                        or return
                    case '*'
                        if test -e requirements.txt
                            pip install -r requirements.txt
                            or return
                        end
                end

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

            case u up update
                if not in_venv
                    print_error "Not in a virtual environment?"
                    return 1
                end

                switch (basename $venv)
                    case continuous-integration2 kernel-dev main
                        if contains $SRC_FOLDER/b4 $packages
                            if not test -d $SRC_FOLDER/b4
                                mkdir -p $SRC_FOLDER
                                and git clone https://git.kernel.org/pub/scm/utils/b4/b4.git/ $SRC_FOLDER/b4
                            end
                            or return

                            git -C $SRC_FOLDER/b4 urh
                            or return
                        end
                        pip install --upgrade pip $packages
                        or return
                    case '*'
                        set packages_to_upgrade (pip list -o | string match -r '^.*[0-9]+\.[0-9]+\.[0-9]+' | string split -f 1 ' ')
                        if test -n "$packages_to_upgrade"
                            pip install --upgrade $packages_to_upgrade
                        end
                end

            case x exit
                if not in_venv
                    print_error "Not in a virtual environment?"
                    return 1
                end
                deactivate
        end
    end
end
