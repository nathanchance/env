#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_bld_tot_tcs -d "Build LLVM and binutils from source for kernel development"
    in_container_msg -c; or return

    for arg in $argv
        switch $arg
            case --lto
                set lto true
        end
    end

    switch $LOCATION
        case aadp generic wsl
            set bld_llvm_args \
                --pgo kernel-defconfig
            set validate_uprev llvm

        case hetzner-server workstation
            set bld_llvm_args \
                --bolt \
                --pgo kernel-defconfig
            set validate_uprev kernel

        case honeycomb
            set bld_bntls false

            set bld_llvm_args \
                --pgo kernel-defconfig \
                --targets AArch64 ARM X86

        case pi
            set bld_bntls false

            set bld_llvm_args \
                --build-stage1-only \
                --defines LLVM_PARALLEL_COMPILE_JOBS=(math (nproc) - 1) \
                LLVM_PARALLEL_LINK_JOBS=1 \
                --projects clang lld \
                --targets AArch64 ARM X86

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
                --targets AArch64 ARM X86

        case test-laptop-intel
            set bld_bntls false

            set bld_llvm_args \
                --build-stage1-only \
                --projects clang lld \
                --targets X86

        case vm
            set bld_bntls false

            set bld_llvm_args \
                --pgo kernel-defconfig-slim

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
        set bntls $tc_bld/src/binutils
        if not test -d $bntls
            git clone https://sourceware.org/git/binutils-gdb.git "$bntls"
        end
        if not is_shallow_clone $bntls; and not has_detached_head $bntls
            git -C $bntls pull --rebase; or return
        end

        set bntls_install $CBL_TC_BNTL_STORE/$date_time-(git -C $bntls sh -s --format=%H origin/master)
        if not PATH="/usr/lib/ccache/bin:$PATH" $tc_bld/build-binutils.py \
                $bld_bntls_args \
                --binutils-folder $bntls \
                --build-folder $TMP_BUILD_FOLDER/(status function)/binutils \
                --install-folder $bntls_install \
                --show-build-commands
            set message "build-binutils.py failed"
            print_error "$message"
            tg_msg "$message"
            return 1
        end

        stripall $bntls_install
        cbl_upd_software_symlinks binutils $bntls_install; or return
    end

    set llvm_project $tc_bld/src/llvm-project
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
    # https://github.com/llvm/llvm-project/issues/63699
    set -a reverts https://github.com/llvm/llvm-project/commit/9485d983ac0c56d412c958b40f4e150a3c30ca7c # [InstCombine] Disable generation of fshl/fshr for rotates
    for revert in $reverts
        set -l revert (basename $revert)
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
        set -l base_rev (basename $revision)
        if not crl "$revision?download=true" | git -C $llvm_project ap $git_ap_args
            set message "Failed to apply $base_rev"
            print_error "$message"
            tg_msg "$message"
            return 1
        end
    end

    set bld_llvm $tc_bld
    set llvm_bld $TMP_BUILD_FOLDER/(status function)/llvm
    set common_bld_llvm_args \
        --assertions \
        --build-folder $llvm_bld \
        --check-targets $check_targets \
        --llvm-folder $llvm_project \
        --no-ccache \
        --quiet-cmake \
        --show-build-commands

    if set -q validate_uprev
        if not $tc_bld/build-llvm.py \
                $common_bld_llvm_args \
                --build-stage1-only
            set message "Validation of new LLVM revision failed: LLVM did not build or tests failed!"
            print_error "$message"
            tg_msg "$message"
            return 1
        end

        if test "$validate_uprev" = kernel
            set lsm_location (command grep -F 'lsm.location = Path(src_folder,' $tc_bld/build-llvm.py | string trim)
            if not env PYTHONPATH=$tc_bld python3 -c "from pathlib import Path

import tc_build.utils

from tc_build.kernel import LinuxSourceManager, LLVMKernelBuilder
from tc_build.llvm import LLVMSourceManager

src_folder = Path('$tc_bld/src')

lsm = LinuxSourceManager()
$lsm_location
lsm.patches = list(src_folder.glob('*.patch'))
lsm.tarball.base_download_url = 'https://git.kernel.org/torvalds/t'
lsm.tarball.local_location = lsm.location.with_name(f'{lsm.location.name}.tar.gz')

tc_build.utils.print_header('Preparing Linux source for profiling runs')
lsm.prepare()

kernel_builder = LLVMKernelBuilder()
kernel_builder.folders.build = Path('$llvm_bld/linux')
kernel_builder.folders.source = lsm.location
kernel_builder.matrix = {
    'defconfig': ['ARM', 'Mips', 'PowerPC'],
    'allmodconfig': LLVMSourceManager(Path('$llvm_project')).default_targets(),
}
kernel_builder.toolchain_prefix = Path('$llvm_bld/final')
kernel_builder.build()"
                set message "Validation of new LLVM revision failed: Linux did not build!"
                print_error "$message"
                tg_msg "$message"
                return 1
            end
        end
    end

    set llvm_install $CBL_TC_LLVM_STORE/$date_time-(git -C $llvm_project sh -s --format=%H origin/main)
    if not $tc_bld/build-llvm.py \
            $common_bld_llvm_args \
            $bld_llvm_args \
            --install-folder $llvm_install
        set message "build-llvm.py failed"
        print_error "$message"
        tg_msg "$message"
        return 1
    end

    stripall $llvm_install
    cbl_upd_software_symlinks llvm $llvm_install
end
