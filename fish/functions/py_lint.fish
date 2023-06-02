#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function py_lint -d "Lint Python files"
    for arg in $argv
        switch $arg
            case -q --quick
                set quick true
            case '*'
                set -a files $arg
        end
    end
    if not set -q files
        set files (fd -e py | fzf --ansi --header "Files to lint" --preview 'fish -c "bat {}"' --multi)
        test -z "$files"; and return 0
    end

    if not in_venv
        if not py_venv e main
            print_error "$command could not be found and no suitable virtual environment found!"
            return 1
        end
        set ephemeral true
    end

    for command in flake8 pylint ruff vulture yapf
        if not command -q $command
            test $command = flake8; and set -a command flake8-bugbear
            pip install $command
        end
    end

    # ruff is faster than flake8 and provides many of the benefits so use it when possible
    if git ls-files | grep -Fq ruff.toml
        if ruff check $files
            print_green "\nruff clean"
        else
            print_red "\nnot ruff clean"
        end
    else
        set -a flake8_ignore E501 # line too long
        if flake8 \
                --extend-ignore (string join , $flake8_ignore) \
                $files
            print_green "\nflake8 clean"
        else
            print_red "\nnot flake8 clean"
        end
    end

    if set -q quick
        echo
    else
        set -a pylint_ignore C0114 # missing-module-docstring
        set -a pylint_ignore C0115 # missing-class-docstring
        set -a pylint_ignore C0116 # missing-function-docstring
        set -a pylint_ignore C0301 # line-too-long
        set -a pylint_ignore C0302 # too-many-lines
        set -a pylint_ignore R0902 # too-many-instance-attributes
        set -a pylint_ignore R0903 # too-few-public-methods
        set -a pylint_ignore R0911 # too-many-returns
        set -a pylint_ignore R0912 # too-many-branches
        set -a pylint_ignore R0913 # too-many-arguments
        set -a pylint_ignore R0914 # too-many-locals
        set -a pylint_ignore R0915 # too-many-statements
        set -a pylint_ignore W1509 # subprocess-popen-preexec-fn
        if pylint \
                --disable (string join , $pylint_ignore) \
                --jobs (nproc) \
                $files
            print_green "pylint clean\n"
        else
            print_red "not pylint clean\n"
        end
    end
    if vulture --min-confidence 80 $files
        print_green "vulture clean\n"
    else
        print_red "\nnot vulture clean\n"
    end
    if command -q yapf
        # Purposefully avoid 'yapf' wrapper
        if command yapf --diff --parallel $files
            print_green "yapf clean"
        else
            print_red "\nnot yapf clean"
        end
    end

    if set -q ephemeral
        py_venv x
    end
end
