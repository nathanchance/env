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
        __print_error "no actions specified!"
        return 1
    end
    if not set -q python
        set python python3
    end
    if not set -q venv
        if __in_venv
            set venv (path basename $VIRTUAL_ENV)
        else
            switch $arg
                case c create e enter r rm remove
                    __print_error "venv name not specified!"
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
        case mkosi
            set packages git+https://github.com/systemd/mkosi
        case tuxmake
            set packages tuxmake
    end
    set venv $PY_VENV_DIR/$venv
    mkdir -p $PY_VENV_DIR

    for action in $actions
        switch $action
            case c create
                $python -m venv $venv

            case e enter
                if __in_venv
                    __print_error "Already in a virtual environment?"
                    return 1
                end

                set VIRTUAL_ENV_DISABLE_PROMPT 1
                set activate $venv/bin/activate.fish
                if not test -f $activate
                    __print_error "$venv does not exist, run 'create'?"
                    return 1
                end
                source $activate

            case i in install u up update
                if not __in_venv
                    __print_error "Not in a virtual environment?"
                    return 1
                end

                set venv_name (path basename $venv)
                switch $venv_name
                    case continuous-integration2 kernel-dev main mkosi tuxmake
                        set -l pip_install_args --upgrade

                        if contains $SRC_FOLDER/b4 $packages
                            cbl_clone_repo b4
                            or return

                            git -C $SRC_FOLDER/b4 urh
                            or return
                        else if test "$venv_name" = mkosi
                            # Since we modify this below, we need to force a reinstall to ensure a consistent state
                            set -a pip_install_args --force-reinstall
                        end

                        pip install $pip_install_args pip $packages
                        or return

                        if test $venv_name = mkosi
                            sed -i \
                                -e "s;suite=f\"{context.config.release}-security\";suite=f\"{context.config.release}{'/updates' if context.config.release == 'buster' else '-security'}\";g" \
                                -e "s;install_apt_sources(context, cls.repositories(context, for_image=True));install_apt_sources(context, cls.repositories(context));g" \
                                $venv/lib/python*/site-packages/mkosi/distribution/debian.py
                        end

                    case '*'
                        if string match -qr '^u' $action
                            set packages_to_upgrade (pip list -o | string match -r '^.*[0-9]+\.[0-9]+\.[0-9]+' | string split -f 1 ' ')
                            if test -n "$packages_to_upgrade"
                                pip install --upgrade $packages_to_upgrade
                            end
                        else
                            if test -e requirements.txt
                                pip install -r requirements.txt
                            end
                        end
                        or return
                end

            case l ls list
                echo
                echo "Available virtual environments:"
                echo
                path filter -d $PY_VENV_DIR/* | path basename

            case r rm remove
                rm -fr $venv

            case x exit
                if not __in_venv
                    __print_error "Not in a virtual environment?"
                    return 1
                end
                deactivate
        end
    end
end
