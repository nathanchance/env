#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function kmake -d "Run make with all cores and adjust PATH temporarily"
    if not in_container; and test -z "$OVERRIDE_CONTAINER"
        print_error "This needs to be run in a container!"
        return 1
    end

    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    # Parse arguments
    set i 1
    while test $i -le (count $argv)
        set arg $argv[$i]
        switch $arg
            case 'CCACHE=*' 'NO_CCACHE=*' 'PO=*'
                set arg (string split = $arg)
                set $arg[1] $arg[2]

            case '*=*'
                if string match -qr 'CC=' $arg
                    set cc_was_in_args true
                else
                    set -a make_args $arg
                end
                set arg (string split = $arg)
                set $arg[1] $arg[2]

            case '*/' '*.dtb' '*.i' '*.ko' '*.o' '*.s' all '*'-pkg '*clean' '*config' '*docs' dtbs '*install' '*Image*' kselftest modules mrproper '*'prepare vmlinu'*'
                set -a make_args $arg

            case -C
                set next (math $i + 1)
                set lnx_dir $argv[$next]
                set -a make_args $arg $lnx_dir
                set i $next

            case +s
                set silent false
        end
        set i (math $i + 1)
    end

    # Default values
    if not set -q cc_was_in_args
        set cc_was_in_args false
    end
    if not set -q FORCE_LE
        set FORCE_LE false
    end
    if not set -q lnx_dir
        set lnx_dir $PWD
    end
    if not set -q silent
        set silent true
    end

    # open-coded in_kernel_tree
    if not test -f $lnx_dir/Makefile
        print_error "$lnx_dir does not appear to be a kernel tree!"
        return 1
    end

    # Setup paths
    if test -n "$LLVM"; or string match -q -- "*clang" "$CC"
        set clang true
        if not set -q CC
            if test -n "$LLVM"; and test "$LLVM" = 1
                set CC clang
            else
                if test "$LLVM" != 1; and not rg -q LLVM_SUFFIX $lnx_dir/Makefile
                    print_error "\$LLVM is set to something other than 1 but this kernel does not support that!"
                    return 1
                end
                if string match -qr / -- $LLVM
                    set CC "$LLVM"clang
                else if string match -qr - -- $LLVM
                    set CC clang$LLVM
                end
            end
        end
    else
        set clang false
        if not set -q CC
            set CC "$CROSS_COMPILE"gcc
        end
    end

    if set -q PO
        set -p PATH $PO
    end

    # Check that CC exists
    set CC (string split " " $CC)
    set cc_path (command -v $CC[-1])
    if not test -x "$cc_path"
        print_error "$CC[-1] could not be found or it is not executable!"
        return 1
    end

    # Print information about CC
    set cc_location (dirname $cc_path)
    printf '\n\e[01;32mCompiler location:\e[0m %s\n\n' $cc_location
    printf '\e[01;32mCompiler version:\e[0m %s \n\n' (eval $cc_path --version | head -1)

    # Print information about binutils if necessary
    if not set -q LLVM_IAS
        # LLVM_IAS because default in v5.15 with commit f12b034afeb3 ("scripts/Makefile.clang: default to LLVM_IAS=1")
        if test "$clang" = true; and test -f $lnx_dir/scripts/Makefile.clang
            set LLVM_IAS 1
        else
            set LLVM_IAS 0
        end
    end
    if test "$LLVM_IAS" = 0; or test -z "$LLVM"
        set as_path (command -v "$CROSS_COMPILE"as)
        if not test -x $as_path
            print_error "binutils could not be found or they are not executable!"
            return 1
        end
        set as_location (dirname $as_path)
        if test "$as_location" != "$cc_location"
            printf '\e[01;32mBinutils location:\e[0m %s\n\n' $as_location
        end
        printf '\e[01;32mBinutils version:\e[0m %s \n\n' (eval $as_path --version | head -1)
    end

    # Set silent flag
    if test "$V" = 1; or test "$V" = 2
        set silent false
    end
    if test "$silent" = true
        set silent_make_flag s
    end

    if test "$FORCE_LE" = true; and test -z "$KCONFIG_ALLCONFIG"
        switch $ARCH
            case arm arm64
                if contains allmodconfig $make_args; or contains allyesconfig $make_args
                    set KCONFIG_ALLCONFIG /tmp/force-le.config
                    echo CONFIG_CPU_BIG_ENDIAN=n >$KCONFIG_ALLCONFIG
                    set -a make_args KCONFIG_ALLCONFIG=$KCONFIG_ALLCONFIG
                end
        end
    end

    if command -q ccache; and test "$CCACHE" != 0; and test "$CCACHE" != false; and test "$NO_CCACHE" != 1; and test "$NO_CCACHE" != false
        set -p make_args CC="ccache $CC"
    else
        if test "$cc_was_in_args" = true
            set -p make_args CC="$CC"
        end
    end

    # make might be an alias, we want that actual binary
    set make_binary (command -v make)

    set fish_trace 1
    time stdbuf -eL -oL $make_binary -"$silent_make_flag"kj(nproc) $make_args
end
