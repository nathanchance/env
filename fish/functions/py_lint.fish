#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function py_lint -d "Lint Python files"
    if test (count $argv) -gt 0
        set files $argv
    else
        set files (fd -e py | fzf --ansi --header "Files to lint" --preview 'fish -c "bat {}"' --multi)
        test -z "$files"; and return 0
    end

    for command in pylint vulture yapf
        if not command -q $command
            if in_venv
                pip install $command
            else
                print_error "$command could not be found and you are not in a virtual environment!"
                return 1
            end
        end
    end

    set -a pylint_ignore C0114 # missing-module-docstring
    set -a pylint_ignore C0115 # missing-class-docstring
    set -a pylint_ignore C0116 # missing-function-docstring
    set -a pylint_ignore C0301 # line-too-long
    set -a pylint_ignore R0902 # too-many-instance-attributes
    set -a pylint_ignore R0903 # too-few-public-methods
    set -a pylint_ignore R0911 # too-many-returns
    set -a pylint_ignore R0912 # too-many-branches
    set -a pylint_ignore R0914 # too-many-locals
    set -a pylint_ignore R0915 # too-many-statements
    if pylint \
            --disable (string join , $pylint_ignore) \
            --jobs (nproc) \
            $files
        print_green "pylint clean\n"
    else
        print_red "not pylint clean\n"
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
end
