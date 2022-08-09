#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_qualify_tc_bld_uprev -d "Qualify a new known good revision for tc-build"
    in_container_msg -c; or return

    if not test -f $HOME/.muttrc.notifier
        print_error "This function runs cbl_lkt, which requires the notifier!"
        return 1
    end

    set tc_bld_src $CBL_GIT/tc-build
    set lnx_stbl $CBL_SRC/linux-stable

    mkdir -p $CBL_TMP
    set work_dir (mktemp -d -p $CBL_TMP)
    set tc_bld (mktemp -d -p $work_dir -u)
    set usr $work_dir/usr
    set linux_srcs $work_dir/linux-stable-$CBL_STABLE_VERSIONS

    header "Setting up folders"

    if not test -d $tc_bld_src
        mkdir -p (dirname $tc_bld_src)
        git clone https://github.com/ClangBuiltLinux/tc-build $tc_bld_src; or return
    end
    git -C $tc_bld_src pull -q -r; or return

    if not test -d $lnx_stbl
        mkdir -p (dirname $lnx_stbl)
        git clone https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git $lnx_stbl; or return
    end
    git -C $lnx_stbl ru; or return

    git -C $tc_bld_src worktree add $tc_bld (git -C $tc_bld_src rev-parse --abbrev-ref --symbolic-full-name @{u}); or return
    for linux_src in $linux_srcs
        git -C $lnx_stbl worktree add $linux_src origin/(string replace 'stable-' '' (basename $linux_src)).y; or return
    end

    header "Building toolchains"

    $tc_bld/build-binutils.py --install-folder $usr; or return

    set common_tc_bld_args \
        --assertions \
        --check-targets clang ll{d,vm{,-unit}} \
        --use-good-revision
    set pgo_arg --pgo kernel-{def,allmod}config

    # Check that two stage build works fine
    $tc_bld/build-llvm.py \
        $common_tc_bld_args; or return 125

    # Check that kernel build works okay with PGO
    $tc_bld/build-llvm.py \
        $common_tc_bld_args \
        $pgo_arg; or return 125

    # Check that ThinLTO alone works okay
    $tc_bld/build-llvm.py \
        $common_tc_bld_args \
        --lto thin; or return 125

    # Check that full LTO alone works okay
    $tc_bld/build-llvm.py \
        $common_tc_bld_args \
        --lto full; or return 125

    # Check that PGO + ThinLTO works okay
    $tc_bld/build-llvm.py \
        $common_tc_bld_args \
        --lto thin \
        $pgo_arg; or return 125

    # Check that PGO + ThinLTO with only ARM targets works okay (because some people are weird like that).
    # Cannot build the tests because they assume the host (X86) is in the list of targets.
    # This is only necessary on x86_64, as this will just work on aarch64.
    if test (uname -n) = x86_64
        $tc_bld/build-llvm.py \
            --assertions \
            --lto thin \
            $pgo_arg \
            --targets "AArch64;ARM" \
            --use-good-revision; or return 125
    end

    # Finally, build with PGO and full LTO
    $tc_bld/build-llvm.py \
        $common_tc_bld_args \
        --install-folder $usr \
        --lto full \
        $pgo_arg; or return 125

    header "Toolchain information"

    $usr/bin/clang --version
    git -C $tc_bld/llvm-project show -s

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
