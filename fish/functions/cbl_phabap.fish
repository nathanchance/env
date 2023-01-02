#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_phabap -d "Apply a patch from LLVM's Phabricator instance"
    if test -z "$LLVM_FOLDER"
        set LLVM_FOLDER $PWD
    end
    if not test -d $LLVM_FOLDER/llvm
        print_error "You are not in an LLVM folder"
        return 1
    end

    for arg in $argv
        switch $arg
            case 'D*'
                set revision $arg
            case '*'
                set -a git_ap_args $arg
        end
    end

    crl "https://reviews.llvm.org/$revision?download=true" | git -C $LLVM_FOLDER ap $git_ap_args; or return
    git ac -m "$revision

Link: https://reviews.llvm.org/$revision"
end
