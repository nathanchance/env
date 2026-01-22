#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_lkt -d "Tests a Linux kernel with llvm-kernel-testing"
    __in_container_msg -c; or return

    set i 1
    set argc (count $argv)
    while test $i -le $argc
        set arg $argv[$i]
        switch $arg
            ##########################
            # Arguments to 'main.py' #
            ##########################
            case -a --architectures -t --targets
                set -a build_py_args $arg
                set i (math $i + 1)
                while test $i -le $argc
                    set arg $argv[$i]
                    if string match -qr '^-' -- $arg
                        set i (math $i - 1)
                        break
                    end
                    set -a build_py_args $arg
                    set i (math $i + 1)
                end

            case -b --build-folder --boot-utils-folder
                set next (math $i + 1)
                set -a build_py_args $arg (realpath -m $argv[$next])
                set i $next

            case --binutils-prefix
                set next (math $i + 1)
                set binutils_prefix $argv[$next]
                set i $next

            case -l --linux-folder
                set next (math $i + 1)
                set linux_folder (realpath $argv[$next])
                set i $next

            case --llvm-prefix
                set next (math $i + 1)
                set llvm_prefix $argv[$next]
                set i $next

            case --qemu-prefix
                set next (math $i + 1)
                set qemu_prefix $argv[$next]
                set i $next

            case --only-test-boot --save-objects --use-ccache
                set -a build_py_args $arg

            case --tc-prefix
                set next (math $i + 1)
                set tc_prefix $argv[$next]
                set i $next

                ##########################
                # Arguments to 'cbl_lkt' #
                ##########################
            case --no-timeout
                set no_timeout true

            case -s --system-binaries
                set system_binaries true

            case --tree
                set next (math $i + 1)
                set tree $argv[$next]
                set i $next

            case '*'
                __print_error "Invalid argument: '$arg'"
                return 1
        end
        set i (math $i + 1)
    end

    if test -z "$linux_folder"
        if test -z "$tree"
            set tree linux-next
        end
        set linux_folder $CBL_SRC_P/$tree
    end

    # We assume that the dependencies are available in an image other than nathan/dev/arch
    if test "$system_binaries" != true
        if test -z "$llvm_prefix$binutils_prefix$tc_prefix"
            if test -e $CBL_TC_BNTL
                set binutils_prefix (path dirname $CBL_TC_BNTL)
            end
            if test -e $CBL_TC_LLVM
                set llvm_prefix (path dirname $CBL_TC_LLVM)
            end
        end
        if test -z "$qemu_prefix"; and test -e $CBL_QEMU
            set qemu_prefix $CBL_QEMU
        end
    end

    if test -n "$binutils_prefix"
        if not test -d $binutils_prefix/bin
            __print_error "$binutils_prefix value is wrong, no bin folder"
            return 1
        end

        set -l as_found false
        for binutils_binary in $binutils_prefix/bin/*
            switch (path basename $binutils_binary)
                case as '*'-linux-gnu'*'-as
                    set as_found true
            end
        end

        if test "$as_found" != true
            __print_error "GNU as could not be found in $binutils_prefix/bin"
            return 1
        end

        set -a build_py_args --binutils-prefix $binutils_prefix
    end

    if test -n "$llvm_prefix"
        if not test -d $llvm_prefix/bin
            __print_error "$llvm_prefix value is wrong, no bin folder"
            return 1
        end

        for clang_binary in $llvm_prefix/bin/clang*
            true
        end

        if test -z "$clang_binary"
            __print_error "clang could not be found in $tc_prefix/bin"
            return 1
        end

        set -a build_py_args --llvm-prefix $llvm_prefix
    end

    if test -n "$tc_prefix"
        if not test -d $tc_prefix/bin
            __print_error "$tc_prefix value is wrong, no bin folder"
            return 1
        end

        set -l as_found false
        set -l clang_found false
        for tc_binary in $tc_prefix/bin/*
            switch (path basename $tc_binary)
                case as '*'-linux-gnu'*'-as
                    set as_found true
                case clang
                    set clang_found true
            end
        end

        if test "$as_found" != true
            __print_error "GNU as could not be found in $tc_prefix/bin"
            return 1
        end

        if test "$clang_found" != true
            __print_error "clang could not be found in $tc_prefix/bin"
            return 1
        end

        set -a build_py_args --tc-prefix $tc_prefix
    end

    if test -n "$qemu_prefix"
        for qemu_binary in $qemu_prefix/bin/qemu-system-'*'
            true
        end

        if test -z "$qemu_binary"
            __print_error "QEMU could not be found in $qemu_prefix/bin"
            return 1
        end

        set -a build_py_args --qemu-prefix $qemu_prefix
    end

    if not string match -qr -- --build-folder $build_py_args
        set -a build_py_args --build-folder (tbf (status function))/(path basename $linux_folder)
    end

    set log_folder $CBL_LOGS/(path basename $linux_folder)-(date +%F-%T)
    mkdir -p $log_folder

    if __is_github_actions
        set lkt $GITHUB_WORKSPACE/lkt
    else
        set lkt $CBL_LKT
        cbl_clone_repo (path basename $lkt)
        if not __is_location_primary
            git -C $lkt urh
        end
    end

    set lkt_cmd \
        $lkt/build.py \
        --linux-folder $linux_folder \
        --log-folder $log_folder \
        $build_py_args

    # Only apply timeout when running interactively, as timeout from boot-qemu.py can get wedged
    if status is-interactive
        switch $LOCATION
            case aadp
                set average_duration 10
            case generic
                if test (nproc) -ge 80
                    set average_duration 5
                else if test (nproc) -ge 64
                    set average_duration 6
                else if test (nproc) -ge 32
                    set average_duration 7
                else if test (nproc) -ge 16
                    set average_duration 8
                end
            case hetzner
                set average_duration 5
            case honeycomb
                set average_duration 4
            case test-desktop-intel-11700
                set average_duration 8
            case workstation
                set average_duration 4
        end
        if set -q average_duration; and not set -q no_timeout
            set -p lkt_cmd \
                timeout (math 1.5 x $average_duration)h
        end
    end

    print_cmd $lkt_cmd
    $lkt_cmd
    set lkt_ret $status

    if test $lkt_ret -ne 0
        if test $lkt_ret -eq 130
            rm -fr $log_folder
        else
            set msg "build.py failed in $linux_folder (ret: $lkt_ret)"
            __print_error "$msg"
            __tg_msg "$msg"
        end
        return $lkt_ret
    end

    set report $log_folder/report.txt
    cbl_gen_build_report $log_folder
    set log_files (PYTHONPATH=$PYTHON_FOLDER python3 -c "from pathlib import Path
import lib.utils

# Gmail has a maximum attachment size of 25MB
MAX_SIZE = 25000000

total_size = 0
files = []

# Filter out zero sized files
for file in sorted((log_folder := Path('$log_folder')).glob('*.log')):
    if (file_size := file.stat().st_size) > 0:
        files.append(file)
        total_size += file_size

# Create a tarball of logs if attachment size is too large
if total_size > MAX_SIZE:
    if (tarball := Path(log_folder, 'logs.tar.zst')).exists():
        tarball.unlink()

    cmd = [
        'tar',
        '--create',
        '--directory', log_folder,
        '--file', tarball,
        '--zstd',
    ]
    cmd += [str(file.relative_to(log_folder)) for file in files]
    lib.utils.run(cmd)

    if tarball.stat().st_size > MAX_SIZE:
        raise RuntimeError('Tarball is greater than 25MB??')

    print(tarball)

# Otherwise, just print the files for attaching via __mail_msg
else:
    for file in files:
        print(str(file))")
    __mail_msg $report $log_files

    echo "Full logs available at: $log_folder"
    echo
end
