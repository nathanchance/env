#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bldtcs -d "Build LLVM and binutils from source for kernel development"
    for arg in $argv
        switch $arg
            case --lto
                set lto true
        end
    end

    switch $LOCATION
        case generic server
            set bld_llvm_args \
                --pgo kernel-{def,allmod}config

        case pi
            set bld_bntls_args \
                --targets host x86_64

            set bld_llvm_args \
                --build-stage1-only \
                --install-stage1-only \
                --projects "clang;lld" \
                --targets "AArch64;ARM;X86"

            set check_targets clang llvm{,-unit}

        case vm
            set bld_bntls_args \
                --targets x86_64

            set bld_llvm_args \
                --pgo kernel-defconfig \
                --targets X86

        case wsl
            set bld_llvm_args \
                --pgo kernel-defconfig
    end
    if not set -q check_targets
        set check_targets clang ll{d,vm{,-unit}}
    end
    if test "$lto" = true
        set -a bld_llvm_args --lto=thin
    end

    set date_time (date +%F_%H-%M-%S)

    if test -f $HOME/.ssh/id_ed25519
        set github_prefix git@github.com:
    else
        set github_prefix https://github.com/
    end

    if not test -d $CBL_TC_BLD
        mkdir -p (dirname $CBL_TC_BLD)
        git clone -b personal "$github_prefix"nathanchance/tc-build.git $CBL_TC_BLD
    end

    set bntls $CBL_TC_BLD/binutils
    if not test -d $bntls
        git clone https://sourceware.org/git/binutils-gdb.git "$bntls"
    end
    git -C $bntls pull --rebase; or return

    set bntls_install $CBL_STOW_BNTL/$date_time-(git -C $bntls sh -s --format=%H origin/master)
    if not PATH="/usr/lib/ccache/bin:$PATH" $CBL_TC_BLD/build-binutils.py $bld_bntls_args --install-folder $bntls_install
        set message "build-binutils.py failed"
        print_error "$message"
        tg_msg "$message"
        return 1
    end
    stripall $bntls_install
    ln -fnrsv $bntls_install (dirname $CBL_BNTL)

    set llvm_project $CBL_TC_BLD/llvm-project
    if not test -d $llvm_project
        git clone https://github.com/llvm/llvm-project $llvm_project
    end
    git -C $llvm_project rh
    if not git -C $llvm_project pull --rebase
        set message "llvm-project failed to rebase/update"
        print_error "$message"
        tg_msg "$message"
        return 1
    end

    # Add patches to revert here
    for revert in $reverts
        if not git -C $llvm_project rv -n $revert
            set message "Failed to revert $revert"
            print_error "$message"
            tg_msg "$message"
            return 1
        end
    end

    # Add in-review patches here
    for revision in $revisions
        if not crl "https://reviews.llvm.org/$revision?download=true" | git -C $llvm_project ap
            set message "Failed to apply $revision"
            print_error "$message"
            tg_msg "$message"
            return 1
        end
    end

    set llvm_install $CBL_STOW_LLVM/$date_time-(git -C $llvm_project sh -s --format=%H origin/main)
    if not $CBL_TC_BLD/build-llvm.py \
            --assertions \
            --check-targets $check_targets \
            --install-folder $llvm_install \
            $bld_llvm_args \
            --show-build-commands
        set message "build-llvm.py failed"
        print_error "$message"
        tg_msg "$message"
        return 1
    end
    stripall $llvm_install
    ln -fnrsv $llvm_install (dirname $CBL_LLVM)

    stow -d $CBL_STOW -R -v (basename (dirname $CBL_BNTL)) (basename (dirname $CBL_LLVM))
end
