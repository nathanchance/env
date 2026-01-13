#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_bld_tot_tcs -d "Build LLVM and binutils from source for kernel development"
    __in_container_msg -c; or return

    for arg in $argv
        switch $arg
            case --lto
                set lto true
        end
    end

    set func_bld (tbf (status function))

    switch $LOCATION
        case aadp hetzner workstation
            set bolt true
            set pgo kernel-defconfig
            set validate_uprev kernel

        case framework-desktop honeycomb test-desktop-amd-8745HS test-desktop-intel-11700
            set bld_bntls false
            set pgo kernel-defconfig
            set targets AArch64 ARM X86
            if test $LOCATION = honeycomb
                set validate_targets "    'defconfig': ['AArch64', 'ARM', 'X86'],"
            else
                set validate_targets "    'defconfig': ['ARM'],
    'allmodconfig': ['AArch64', 'ARM', 'X86'],"
            end
            set validate_uprev kernel

        case chromebox test-desktop-intel-n100 test-laptop-intel
            set bld_bntls false
            set bld_stage_one_only true
            set projects clang lld
            set targets AArch64 ARM X86

        case generic
            set bolt true
            set pgo kernel-defconfig
            set validate_uprev llvm

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

    if __is_github_actions
        set tc_bld $GITHUB_WORKSPACE/tc-build
    else
        set tc_bld $CBL_TC_BLD
        cbl_clone_repo $tc_bld
        if not __is_location_primary
            git -C $tc_bld urh
        end
    end

    if test "$bld_bntls" != false
        set bntls $tc_bld/src/binutils
        if not test -d $bntls
            __clone_repo_from_bundle (path basename $bntls) "$bntls"
        end
        if not __is_shallow_clone $bntls; and not __has_detached_head $bntls
            git -C $bntls pull --rebase; or return
        end

        string match -gr "PACKAGE_VERSION='(.*)'" <$bntls/binutils/configure | read bntls_ver
        if test (string split . $bntls_ver | count) != 3
            set message "Malformed binutils version ('$bntls_ver')?"
            __print_error "$messsage"
            __tg_msg "$message"
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
            __print_error "$message"
            __tg_msg "$message"
            return 1
        end

        __stripall $bntls_install
        cbl_upd_software_symlinks binutils $bntls_install; or return
    end

    set llvm_project $tc_bld/src/llvm-project
    if not test -d $llvm_project
        __clone_repo_from_bundle (path basename $llvm_project) $llvm_project
    end
    if not __is_shallow_clone $llvm_project; and not __has_detached_head $llvm_project
        git -C $llvm_project rh
        if not git -C $llvm_project pull --rebase
            set message "llvm-project failed to rebase/update"
            __print_error "$message"
            __tg_msg "$message"
            return 1
        end
    end

    # Add patches to revert here
    # https://github.com/llvm/llvm-project/pull/171456#issuecomment-3727345950
    # https://github.com/llvm/llvm-project/pull/171456#issuecomment-3741522625
    set -a reverts https://github.com/llvm/llvm-project/commit/a83c89495ba6fe0134dcaa02372c320cc7ff0dbf # Reapply [ConstantInt] Disable implicit truncation in ConstantInt::get() (#171456)
    for revert in $reverts
        if string match -qr 'https?://' $revert
            set -l revert (path basename $revert)
            if not git -C $llvm_project rv -n $revert
                set message "Failed to revert $revert"
                __print_error "$message"
                __tg_msg "$message"
                return 1
            end
        else
            if not git -C $llvm_project ap $revert
                set message "Failed to apply $revert"
                __print_error "$message"
                __tg_msg "$message"
                return 1
            end
        end
    end

    # Add in-review patches here
    # https://github.com/ClangBuiltLinux/linux/issues/2130
    set -a gh_prs https://github.com/llvm/llvm-project/pull/174480 # [CodeGen] Check BlockAddress users before marking block as taken
    for gh_pr in $gh_prs
        if gh_llvm pr view --json state (path basename $gh_pr) | python3 -c "import json, sys; sys.exit(0 if json.load(sys.stdin)['state'] == 'MERGED' else 1)"
            __print_warning "$gh_pr has already been merged, skipping..."
            continue
        end

        if not gh_llvm pr diff (path basename $gh_pr) | git -C $llvm_project ap
            set message "Failed to apply $gh_pr"
            __print_error "$message"
            __tg_msg "$message"
            return 1
        end
    end

    string match -gr "\s+set\(LLVM_VERSION_[A-Z]+ ([0-9]+)\)" <$llvm_project/cmake/Modules/LLVMVersion.cmake | string join . | read llvm_ver
    if test (string split . $llvm_ver | count) != 3
        set message "Malformed LLVM version ('$llvm_ver')?"
        __print_error "$messsage"
        __tg_msg "$message"
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
            __print_error "$message"
            __tg_msg "$message"
            return 1
        end

        if test "$validate_uprev" = kernel
            if not set -q validate_targets
                if set -q targets
                    __print_error "Validate uprev target set to kernel with specific targets but no validation specific targets?"
                    return 1
                end

                set validate_targets "    'defconfig': ['ARM', 'Mips', 'PowerPC'],
    'allmodconfig': LLVMSourceManager(Path('$llvm_project')).default_targets(),"
            end

            cbl_clone_repo $CBL_LKT
            or return
            if not __is_location_primary
                git -C $CBL_LKT urh
            end

            set lsm_location (string match -er 'lsm\.location = Path\(src_folder,' <$tc_bld/build-llvm.py | string trim)
            timeout 24h env PYTHONPATH=$tc_bld:$CBL_LKT python3 -c "from os import environ as e
from pathlib import Path

import lkt.source
from lkt.runner import Folders
from lkt.x86_64 import X8664LLVMKernelRunner

import tc_build.kernel
import tc_build.utils
from tc_build.llvm import LLVMSourceManager

src_folder = Path('$tc_bld/src')

tcb_lsm = tc_build.kernel.LinuxSourceManager()
tcb_$lsm_location
tcb_lsm.patches = list(src_folder.glob('*.patch'))
tcb_lsm.tarball.base_download_url = 'https://git.kernel.org/torvalds/t'
tcb_lsm.tarball.local_location = tcb_lsm.location.with_name(f'{tcb_lsm.location.name}.tar.gz')

tc_build.utils.print_header('Preparing Linux source for profiling runs')
tcb_lsm.prepare()

folders = Folders()
folders.source = tcb_lsm.location
folders.build = Path('$llvm_bld/linux')
folders.log = Path(e['CBL_LOGS'], 'cbl_bld_tot_tcs')

runner = X8664LLVMKernelRunner()
runner.configs = [Path(e['CBL_LKT'], 'configs/archlinux/x86_64.config')]
runner.folders = folders
runner.lsm = lkt.source.LinuxSourceManager(folders.source)
runner.make_vars['ARCH'] = 'x86_64'

kernel_builder = tc_build.kernel.LLVMKernelBuilder()
kernel_builder.folders.build = folders.build
kernel_builder.folders.source = folders.source
kernel_builder.matrix = {
$validate_targets
}
kernel_builder.toolchain_prefix = Path('$llvm_bld/final')

folders.log.mkdir(parents=True, exist_ok=True)
runner.run()
kernel_builder.build()"
            switch $status
                case 0 # ok
                case 124
                    set failure_reason "Building Linux timed out"
                case '*'
                    set failure_reason "Linux did not build"
            end
            if set -q failure_reason
                set message "Validation of new LLVM revision failed: $failure_reason!"
                __print_error "$message"
                __tg_msg "$message"
                return 1
            end
        end
    end

    if set -q bld_stage_one_only
        set -a bld_llvm_args --build-stage1-only
    end
    if set -q bolt
        # If /tmp size is less than 10GB, define TMPDIR within the build folder
        # so that we do not potentially error when working with large perf
        # profiles.
        if test (findmnt -n -o OPTIONS /tmp | string match -gr 'size=(\d+)k') -lt 10000000
            set -fx TMPDIR $llvm_bld/tmp
            remkdir $TMPDIR
        end
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
        __print_error "$message"
        __tg_msg "$message"
        return 1
    end

    __stripall $llvm_install
    cbl_upd_software_symlinks llvm $llvm_install
end
