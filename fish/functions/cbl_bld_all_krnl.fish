#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_bld_all_krnl -d "Build all kernels for ClangBuiltLinux testing"
    __in_container_msg -c; or return

    set lnx_src $CBL_SRC_C/linux

    switch $LOCATION
        case aadp framework-desktop generic honeycomb test-desktop-amd-8745HS test-desktop-intel-11700
            cbl_upd_src c m

            set slim_architectures --architectures arm arm64 i386 x86_64
            switch $LOCATION
                case framework-desktop test-desktop-amd-8745HS test-desktop-intel-11700
                    # Fewer architectures
                    set -a cbl_lkt_args \
                        $slim_architectures

                case honeycomb
                    # Fewer architectures and only defconfigs
                    set -a cbl_lkt_args \
                        $slim_architectures \
                        --targets def
            end

            cbl_lkt \
                --linux-folder $lnx_src \
                $cbl_lkt_args

        case chromebox test-desktop-intel-n100 test-laptop-intel
            cbl_test_kvm build
            or return

            if test -e $CBL_TC_LLVM/clang
                set tc_arg LLVM=1
            else
                set tc_arg (korg_llvm var)
            end

            kmake \
                -C $lnx_src \
                KCONFIG_ALLCONFIG=(print_no_werror_cfgs | psub) \
                $tc_arg \
                O=(tbf $lnx_src) \
                distclean allmodconfig all

        case '*'
            for arg in $argv
                switch $arg
                    case -l --lts
                        set lts true
                    case -s --short
                        set short true
                end
            end
            set trees linux-next linux
            if not test "$short" = true
                set -a trees linux-stable-$CBL_STABLE_VERSIONS[1]
            end
            if test "$lts" = true
                set -a trees linux-stable-$CBL_STABLE_VERSIONS[2..-1]
            end
            for tree in $trees
                cbl_lkt --tree $tree; or break
            end
    end
end
