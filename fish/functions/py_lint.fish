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

    set commands pylint vulture yapf
    if git ls-files | string match -qr 'ruff\.toml'
        set -a commands ruff
    else
        set -a commands flake8
    end

    # ruff is faster than flake8 and provides many of the benefits so use it when possible
    if contains ruff $commands
        if uvx ruff check $files
            __print_green "\nruff clean"
        else
            __print_red "\nnot ruff clean"
        end
    else
        set -a flake8_ignore E501 # line too long
        if uvx flake8 \
                --extend-ignore (string join , $flake8_ignore) \
                $files
            __print_green "\nflake8 clean"
        else
            __print_red "\nnot flake8 clean"
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
        set -a pylint_ignore R0801 # duplicate-code
        set -a pylint_ignore R0902 # too-many-instance-attributes
        set -a pylint_ignore R0903 # too-few-public-methods
        set -a pylint_ignore R0911 # too-many-returns
        set -a pylint_ignore R0912 # too-many-branches
        set -a pylint_ignore R0913 # too-many-arguments
        set -a pylint_ignore R0914 # too-many-locals
        set -a pylint_ignore R0915 # too-many-statements
        set -a pylint_ignore R0917 # too-many-positional-arguments
        set -a pylint_ignore W1509 # subprocess-popen-preexec-fn
        if uvx pylint \
                --disable (string join , $pylint_ignore) \
                --jobs (nproc) \
                $files
            __print_green "pylint clean\n"
        else
            __print_red "not pylint clean\n"
        end
    end
    if uvx vulture --min-confidence 80 $files
        __print_green "vulture clean\n"
    else
        __print_red "\nnot vulture clean\n"
    end
    if uvx yapf --diff --parallel $files
        __print_green "yapf clean"
    else
        __print_red "\nnot yapf clean"
    end
end
