#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function run_cmd -d "Run specified command depending on where it is available"
    set cmd $argv[1]
    switch $cmd
        case b4 lei tuxmake
            set -fx XDG_CACHE_HOME $XDG_FOLDER/cache
            set -fx XDG_CONFIG_HOME $XDG_FOLDER/config
            set -fx XDG_DATA_HOME $XDG_FOLDER/share

            if test $cmd = tuxmake
                set -fx CONTAINERS_STORAGE_CONF $ENV_FOLDER/configs/tuxmake/storage.conf
            end

        case duf
            set cmd_def_args \
                -style ascii

        case fzf
            set -fx TMPDIR /var/tmp/fzf

        case yapf
            set cmd_def_args \
                --in-place \
                --parallel
    end

    set cmd_args \
        $cmd_def_args \
        $argv[2..-1]

    set simple_cmd $BIN_FOLDER/$cmd
    set nested_cmd $simple_cmd/bin/$cmd

    if command -q $cmd
        command $cmd $cmd_args
    else if test -f $simple_cmd; and test -x $simple_cmd
        $simple_cmd $cmd_args
    else if test -f $nested_cmd; and test -x $nested_cmd
        switch $cmd
            case tmuxp
                set -p nested_cmd PYTHONPATH=$simple_cmd
        end
        env $nested_cmd $cmd_args
    else
        switch $cmd
            case b4 tuxmake
                set git_repo $BIN_SRC_FOLDER/$cmd
                switch $cmd
                    case b4
                        set cmd_path $git_repo/$cmd.sh
                    case tuxmake
                        if string match -qr podman -- $cmd_argv
                            in_container_msg -h; or return
                        end
                        set cmd_path $git_repo/run
                end
                if not test -e $cmd_path
                    print_error "$cmd checkout could not be found, download it with 'upd $cmd'."
                    return 1
                end
                $cmd_path $cmd_args

            case duf
                df -hT

            case eza
                command ls --color=auto $cmd_args

            case yapf
                switch $cmd
                    case yapf
                        set python_path $BIN_SRC_FOLDER/$cmd
                        set cmd_path python3 $python_path/$cmd
                end
                if not test -d $python_path
                    print_error "$cmd package could not be found, download it with 'upd $cmd'."
                    return 1
                end
                PYTHONPATH=$python_path $cmd_path $cmd_args

            case '*'
                print_error "$cmd could not be found, it might be installable via 'upd $cmd'."
                return 1
        end
    end
end
