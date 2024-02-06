#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_qualify_tc_bld_uprev -d "Qualify a new known good revision for tc-build"
    in_container_msg -c; or return

    if not test -f $HOME/.muttrc.notifier
        print_error "This function runs cbl_lkt, which requires the notifier!"
        return 1
    end

    set tc_bld_src $CBL_GIT/tc-build
    set lnx_stbl $CBL_BLD_C/linux-stable

    begin
        cbl_upd_lnx_c s
        and cbl_clone_repo (basename $tc_bld_src)
        and git -C $tc_bld_src ru -p
    end
    or return

    if test -n "$argv[1]"
        set tc_bld_branch $argv[1]
    else
        set tc_bld_branch (git -C $tc_bld_src rev-parse --abbrev-ref --symbolic-full-name @{u})
    end

    mkdir -p $CBL_TMP
    set work_dir (mktemp -d -p $CBL_TMP)
    set tc_bld (mktemp -d -p $work_dir -u)
    set usr $work_dir/usr
    set linux_srcs $work_dir/linux-stable-$CBL_STABLE_VERSIONS

    header "Setting up folders"

    git -C $tc_bld_src worktree add $tc_bld $tc_bld_branch; or return
    for linux_src in $linux_srcs
        git -C $lnx_stbl worktree add $linux_src origin/(stable_folder_to_branch $linux_src); or return
    end

    header "Building toolchains"

    $tc_bld/build-binutils.py --install-folder $usr; or return

    set common_tc_bld_args \
        --assertions \
        --check-targets clang ll{d,vm{,-unit}} \
        --quiet-cmake \
        --show-build-commands \
        --use-good-revision
    set pgo_arg --pgo kernel-{def,allmod}config
    # LTO and ThinLTO can cause jobs to run out of memory on systems with a
    # large number of cores and not so much RAM, like my 80-core, 128GB RAM
    # Ampere system. Limit the number of link jobs with LTO to avoid this
    # problem, as recommended in LLVM's cmake documentation:
    # https://www.llvm.org/docs/CMake.html#frequently-used-llvm-related-variables
    set lto_mem (python3 -c "import os
gib = int(os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES') / 1024**3)
print(gib // 30, gib // 15)" | string split ' ')
    set full_lto_def --defines LLVM_PARALLEL_LINK_JOBS=$lto_mem[1]
    set thin_lto_def --defines LLVM_PARALLEL_LINK_JOBS=$lto_mem[2]

    begin
        # Check that two stage build works fine
        $tc_bld/build-llvm.py \
            $common_tc_bld_args

        # Check that kernel build works okay with PGO
        and $tc_bld/build-llvm.py \
            $common_tc_bld_args \
            $pgo_arg

        # Check that ThinLTO alone works okay
        and $tc_bld/build-llvm.py \
            $common_tc_bld_args \
            $thin_lto_def \
            --lto thin

        # Check that full LTO alone works okay
        and $tc_bld/build-llvm.py \
            $common_tc_bld_args \
            $full_lto_def \
            --lto full

        # Check that PGO + ThinLTO works okay
        and $tc_bld/build-llvm.py \
            $common_tc_bld_args \
            $thin_lto_def \
            --lto thin \
            $pgo_arg

        # Check that PGO + ThinLTO with only ARM targets works okay (because some people are weird like that).
        # Cannot build the tests because they assume the host (X86) is in the list of targets.
        # This is only necessary on x86_64, as this will just work on aarch64.
        and if test (uname -n) = x86_64
            $tc_bld/build-llvm.py \
                --assertions \
                $thin_lto_def \
                --lto thin \
                $pgo_arg \
                --targets "AArch64;ARM" \
                --use-good-revision
        end

        # Finally, build with PGO and full LTO
        and $tc_bld/build-llvm.py \
            $common_tc_bld_args \
            --install-folder $usr \
            $full_lto_def \
            --lto full \
            $pgo_arg
    end
    or return 125

    header "Toolchain information"

    $usr/bin/clang --version
    git -C $tc_bld/src/llvm-project show -s

    header "Testing toolchain"

    for linux_src in $linux_srcs
        cbl_lkt --linux-folder $linux_src --tc-prefix $usr
    end

    header "Removing worktrees"

    git -C $tc_bld_src worktree remove --force $tc_bld
    for linux_src in $linux_srcs
        git -C $lnx_stbl worktree remove --force $linux_src
    end
    rm -rf $work_dir
end
