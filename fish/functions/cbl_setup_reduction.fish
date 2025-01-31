#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_setup_reduction -d "Build good and bad versions of LLVM for cvise reductions"
    in_tree llvm
    or return 128

    set bad_sha $argv[1]
    if test -z "$bad_sha"
        print_error "No bad sha provided?"
        return 1
    end
    set bad_sha (git sha $bad_sha)
    or return

    set good_sha $argv[2]
    if test -z "$good_sha"
        set good_sha $bad_sha^
    end
    set good_sha (git sha $good_sha)
    or return

    set bld_llvm_args $argv[3..]

    set -g tmp_dir (mktemp -d -p $TMP_FOLDER -t cvise.XXXXXXXXXX)

    cbl_bld_llvm_sbs \
        $tmp_dir \
        $bad_sha $good_sha \
        $bld_llvm_args
    or return

    for sub_dir in build install
        ln -fnrsv $tmp_dir/$sub_dir/llvm-{$bad_sha,bad}
        or return

        ln -fnrsv $tmp_dir/$sub_dir/llvm-{$good_sha,good}
        or return
    end

    set cvise $tmp_dir/cvise
    mkdir -p $cvise

    set cvise_test $cvise/test.fish
    echo '#!/usr/bin/env fish

set cvise_dir (realpath (status dirname))
set tmp_dir (path dirname $cvise_dir)
set install_dir $tmp_dir/install

set bad_clang $install_dir/llvm-bad/bin/clang
set good_clang $install_dir/llvm-good/bin/clang

############
# PART ONE #
############

set lnx_bld $tmp_dir/build/linux
set lnx_src
set make_args

if test -z "$lnx_src"
    echo "No Linux source folder set?"
    return 1
end
if not test -d $lnx_src
    echo "Linux source does not exist?"
    return 1
end
if test -z "$make_args"
    echo "No make target set?"
    return 1
end
set i_target $make_args[-2]
if not string match -qr \'\.i$\' $i_target
    print_error ".i file is not the second to last target in make_args?"
    return 1
end
set o_target $make_args[-1]
if not string match -qr \'\.o$\' $o_target
    print_error ".o file is not the last target in make_args?"
    return 1
end
set o_cmd_file $lnx_bld/good/(path dirname $o_target)/.(path basename $o_target).cmd

#####################################
# BEWARE MODIFICATIONS TO THIS AREA #
#####################################

function build_kernel
    set type $argv[1]
    set clang_var "$type"_clang

    kmake \
        -C $lnx_src \
        CC=$$clang_var \
        LLVM=1 \
        O=$lnx_bld/$type \
        mrproper $make_args
end

build_kernel good
or return
if not test -f $o_cmd_file
    print_error "$o_cmd_file does not exist?"
    return 1
end

build_kernel bad
set script_ret $status
if test $script_ret -eq 0
    print_error "Bad kernel built successfully? Remove this check if that is expected."
    return 1
end

# Create flags file to minimize flags needed to reproduce issue
head -1 $o_cmd_file | \
    string match -gr -- "-D__KERNEL__ (.*) -c" | \
    sed \'s/ -I.*$//\' | \
    tr " " "\n" | \
    sed "/\//d" >$cvise_dir/flags

set i_file $lnx_bld/bad/$i_target
if not test -f $i_file
    print_error "$i_target could not be found in $lnx_bld/bad?"
    return 1
end
cp -v $i_file $cvise_dir; or return

exit $script_ret

############
# PART TWO #
############

set file
if test -z "$file"
    print_error "Reduction file not set?"
    return 1
end
if not test -e $file
    cp $cvise_dir/$file $file
end

set no_werror_clang
set no_werror_common
set no_werror_gcc

set clang_flags \
    (cat flags) \
    -Wno-error=$no_werror_clang
set common_flags \
    -Wall \
    -Werror \
    -Wfatal-errors \
    -Wno-error=$no_werror_common \
    -c \
    -o /dev/null \
    $file
set gcc_flags \
    -Wno-error=$no_werror_gcc

$good_clang $clang_flags $common_flags
or return

$bad_clang $clang_flags $common_flags &| grep -F \'\'
test "$pipestatus" = "1 0"' >$cvise_test
    chmod +x $cvise_test

    begin
        git -C $cvise init
        and git -C $cvise add test.fish
        and git -C $cvise commit -m "Initial interestingness test"
    end
    or return

    echo "cvise reduction has been prepared at: $tmp_dir"
    bell
end
