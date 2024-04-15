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

    set func_bld (tbf (status function))

    switch $LOCATION
        case aadp generic wsl
            set bolt true
            set pgo kernel-defconfig
            if test $LOCATION = aadp
                set validate_uprev kernel
            else
                set validate_uprev llvm
            end

        case hetzner-server workstation
            set bolt true
            set pgo kernel-defconfig
            set validate_uprev kernel

        case honeycomb test-desktop-intel
            set bld_bntls false
            set pgo kernel-defconfig
            set targets AArch64 ARM X86
            set validate_targets "    'defconfig': ['ARM'],
    'allmodconfig': ['AArch64', 'ARM', 'X86'],"
            set validate_uprev kernel

        case pi
            set bld_bntls false
            set bld_stage_one_only true
            set check_targets clang llvm{,-unit}
            set defines \
                LLVM_PARALLEL_COMPILE_JOBS=(math (nproc) - 1) \
                LLVM_PARALLEL_LINK_JOBS=1
            set projects clang lld
            set targets AArch64 ARM X86

        case test-desktop-amd
            set bld_bntls false
            set pgo kernel-{allmod,def}config
            set targets X86

        case test-laptop-intel
            set bld_bntls false
            set bld_stage_one_only true
            set projects clang lld
            set targets X86

        case vm
            set bld_bntls false

            set pgo kernel-defconfig-slim
    end
    if not set -q check_targets
        set check_targets clang ll{d,vm{,-unit}}
    end
    if test "$lto" = true
        set -a bld_llvm_args --lto thin
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
            clone_repo_from_bundle (basename $bntls) "$bntls"
        end
        if not is_shallow_clone $bntls; and not has_detached_head $bntls
            git -C $bntls pull --rebase; or return
        end

        string match -gr "PACKAGE_VERSION='(.*)'" <$bntls/binutils/configure | read bntls_ver
        if test (string split . $bntls_ver | count) != 3
            set message "Malformed binutils version ('$bntls_ver')?"
            print_error "$messsage"
            tg_msg "$message"
            return 1
        end
        set bntls_install $CBL_TC_BNTL_STORE/$bntls_ver-$date_time-(git -C $bntls sh -s --format=%H origin/master)
        if not PATH="/usr/lib/ccache/bin:$PATH" $tc_bld/build-binutils.py \
                $bld_bntls_args \
                --binutils-folder $bntls \
                --build-folder $func_bld/binutils \
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
        clone_repo_from_bundle (basename $llvm_project) $llvm_project
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
        if string match -qr 'https?://' $revert
            set -l revert (basename $revert)
            if not git -C $llvm_project rv -n $revert
                set message "Failed to revert $revert"
                print_error "$message"
                tg_msg "$message"
                return 1
            end
        else
            if not git -C $llvm_project ap $revert
                set message "Failed to apply $revert"
                print_error "$message"
                tg_msg "$message"
                return 1
            end
        end
    end

    # Add in-review patches here
    for gh_pr in $gh_prs
        if gh_llvm pr view --json state (basename $gh_pr) | python3 -c "import json, sys; sys.exit(0 if json.load(sys.stdin)['state'] == 'MERGED' else 1)"
            print_warning "$gh_pr has already been merged, skipping..."
            continue
        end

        if not gh_llvm pr diff (basename $gh_pr) | git -C $llvm_project ap
            set message "Failed to apply $gh_pr"
            print_error "$message"
            tg_msg "$message"
            return 1
        end
    end

    string match -gr "\s+set\(LLVM_VERSION_[A-Z]+ ([0-9]+)\)" <$llvm_project/cmake/Modules/LLVMVersion.cmake | string join . | read llvm_ver
    if test (string split . $llvm_ver | count) != 3
        set message "Malformed LLVM version ('$llvm_ver')?"
        print_error "$messsage"
        tg_msg "$message"
        return 1
    end

    set bld_llvm $tc_bld
    set llvm_bld $func_bld/llvm
    set common_bld_llvm_args \
        --assertions \
        --build-folder $llvm_bld \
        --check-targets $check_targets \
        --llvm-folder $llvm_project \
        --no-ccache \
        --quiet-cmake \
        --show-build-commands
    if set -q projects
        set -a common_bld_llvm_args --projects $projects
    end
    if set -q targets
        set -a common_bld_llvm_args --targets $targets
    end

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
            if not set -q validate_targets
                if set -q targets
                    print_error "Validate uprev target set to kernel with specific targets but no validation specific targets?"
                    return 1
                end

                set validate_targets "    'defconfig': ['ARM', 'Mips', 'PowerPC'],
    'allmodconfig': LLVMSourceManager(Path('$llvm_project')).default_targets(),"
            end

            set lsm_location (command grep -F 'lsm.location = Path(src_folder,' $tc_bld/build-llvm.py | string trim)
            if not timeout 24h env PYTHONPATH=$tc_bld python3 -c "from pathlib import Path

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
$validate_targets
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

    if set -q bld_stage_one_only
        set -a bld_llvm_args --build-stage1-only
    end
    if set -q bolt
        set -a bld_llvm_args --bolt
    end
    if set -q defines
        set -a defines --defines $defines
    end
    if set -q pgo
        set -a bld_llvm_args --pgo $pgo
    end

    set llvm_install $CBL_TC_LLVM_STORE/$llvm_ver-$date_time-(git -C $llvm_project sh -s --format=%H origin/main)
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
