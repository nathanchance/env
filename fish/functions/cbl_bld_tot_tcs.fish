#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_bld_tot_tcs -d "Build LLVM and binutils from source for kernel development"
    in_container_msg -c; or return

    for arg in $argv
        switch $arg
            case --lto
                set lto true
        end
    end

    switch $LOCATION
        case generic wsl
            set bld_llvm_args \
                --pgo kernel-defconfig

        case hetzner-server workstation
            set bld_llvm_args \
                --bolt \
                --pgo kernel-{allmod,def}config

        case honeycomb
            set bld_bntls false

            set bld_llvm_args \
                --pgo kernel-defconfig \
                --targets "AArch64;ARM;X86"

        case pi
            set bld_bntls false

            set bld_llvm_args \
                --build-stage1-only \
                --defines LLVM_PARALLEL_COMPILE_JOBS=(math (nproc) - 1) \
                LLVM_PARALLEL_LINK_JOBS=1 \
                --install-stage1-only \
                --projects "clang;lld" \
                --targets "AArch64;ARM;X86"

            set check_targets clang llvm{,-unit}

        case test-desktop-amd
            set bld_bntls false

            set bld_llvm_args \
                --pgo kernel-{allmod,def}config \
                --targets X86

        case test-desktop-intel
            set bld_bntls false

            set bld_llvm_args \
                --pgo kernel-{allmod,def}config \
                --targets "AArch64;ARM;X86"

        case test-laptop-intel
            set bld_bntls false

            set bld_llvm_args \
                --build-stage1-only \
                --install-stage1-only \
                --projects "clang;lld" \
                --targets X86

        case vm
            set bld_bntls false

            set bld_llvm_args \
                --pgo kernel-defconfig \
                --targets X86

    end
    if not set -q check_targets
        set check_targets clang ll{d,vm{,-unit}}
    end
    if test "$lto" = true
        set -a bld_llvm_args --lto=thin
    end

    set date_time (date +%F_%H-%M-%S)

    if is_github_actions
        set tc_bld $GITHUB_WORKSPACE/tc-build
    else
        set tc_bld $CBL_TC_BLD
        if not test -d $tc_bld
            mkdir -p (dirname $tc_bld)
            set -l clone_args -b personal
            if gh auth status
                gh repo clone tc-build $tc_bld -- $clone_args
            else
                git clone $clone_args https://github.com/nathanchance/tc-build.git $tc_bld
            end
        end
        if not is_location_primary
            git -C $tc_bld urh
        end
    end

    if test "$bld_bntls" != false
        set bntls $tc_bld/binutils
        if not test -d $bntls
            git clone https://sourceware.org/git/binutils-gdb.git "$bntls"
        end
        if not is_shallow_clone $bntls; and not has_detached_head $bntls
            git -C $bntls pull --rebase; or return
        end

        set bntls_install $CBL_TC_STOW_BNTL/$date_time-(git -C $bntls sh -s --format=%H origin/master)
        if not PATH="/usr/lib/ccache/bin:$PATH" $tc_bld/build-binutils.py \
                $bld_bntls_args \
                --binutils-folder $bntls \
                --build-folder $TMP_BUILD_FOLDER/binutils \
                --install-folder $bntls_install
            set message "build-binutils.py failed"
            print_error "$message"
            tg_msg "$message"
            return 1
        end

        stripall $bntls_install
        cbl_upd_software_symlinks binutils $bntls_install; or return
    end

    set llvm_project $tc_bld/llvm-project
    if not test -d $llvm_project
        git clone https://github.com/llvm/llvm-project $llvm_project
    end
    if not is_shallow_clone $llvm_project; and not has_detached_head $llvm_project
        git -C $llvm_project rh
        if not git -C $llvm_project pull --rebase
            set message "llvm-project failed to rebase/update"
            print_error "$message"
            tg_msg "$message"
            return 1
        end
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
        set -l git_ap_args
        if not crl "https://reviews.llvm.org/$revision?download=true" | git -C $llvm_project ap $git_ap_args
            set message "Failed to apply $revision"
            print_error "$message"
            tg_msg "$message"
            return 1
        end
    end

    set llvm_install $CBL_TC_STOW_LLVM/$date_time-(git -C $llvm_project sh -s --format=%H origin/main)
    if not $tc_bld/build-llvm.py \
            --assertions \
            --build-folder $TMP_BUILD_FOLDER/llvm \
            --check-targets $check_targets \
            --install-folder $llvm_install \
            --llvm-folder $llvm_project \
            $bld_llvm_args \
            --no-ccache \
            --quiet-cmake \
            --show-build-commands
        set message "build-llvm.py failed"
        print_error "$message"
        tg_msg "$message"
        return 1
    end

    stripall $llvm_install
    cbl_upd_software_symlinks llvm $llvm_install
end
