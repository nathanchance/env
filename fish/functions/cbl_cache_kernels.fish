#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function cbl_cache_kernels -d "Download kernels to $NAS_FOLDER for local consumption"
    set kernel_folder $NAS_FOLDER/Kernels
    if not test -d $kernel_folder
        print_error "\$NAS_FOLDER ('$NAS_FOLDER') not mounted?"
        return 1
    end

    if not set tmp_test (mktemp -p $kernel_folder -q -t .tmp.XXXXXXXXXX)
        print_error "\$kernel_folder ('$kernel_folder') not writable?"
        return 1
    end
    rm $tmp_test

    if not set -q remote_user
        set remote_user nathan
    end
    if not set -q remote_host
        set remote_host $MAIN_REMOTE_IP
    end
    if not set -q remote_main_folder
        set remote_main_folder /home/$remote_user
    end
    if not set -q remote_tmp_build_folder
        set remote_tmp_build_folder /mnt/nvme/tmp/build
    end

    # Download linux-next-llvm package
    set krnl linux-next-llvm
    set remote_krnl_bld (tbf $krnl | string replace $TMP_BUILD_FOLDER $remote_tmp_build_folder)
    if ssh $remote_user@$remote_host "test -d $remote_krnl_bld/pkgbuild"
        set subdir pkgbuild/
    end
    set remote_krnl_pkg (ssh $remote_user@$remote_host ls $remote_krnl_bld/"$subdir"$krnl-'*'.tar.zst)
    set remote_krnl_pkg_sha (ssh $remote_user@$remote_host sha512sum $remote_krnl_pkg | string split -f 1 ' ')

    set cached_krnl_pkg $kernel_folder/pkg/(path basename $remote_krnl_pkg)
    if test -e $cached_krnl_pkg; and test (sha512sum $cached_krnl_pkg | string split -f 1 ' ') = "$remote_krnl_pkg_sha"
        print_green "$remote_krnl_pkg already downloaded @ $cached_krnl_pkg"
    else
        scp $remote_user@$remote_host:$remote_krnl_bld/"$subdir"$krnl-'*'.tar.zst $kernel_folder/pkg
        or return
    end

    # Download Fedora package
    set -q krnl_bld; or set krnl_bld (tbf fedora | string replace $TMP_BUILD_FOLDER $remote_tmp_build_folder)
    set remote_rpm_folder (string replace $MAIN_FOLDER $remote_main_folder $krnl_bld)/rpmbuild/RPMS/aarch64
    set remote_krnl_rpm (ssh $remote_user@$remote_host fd -e rpm -u 'kernel-[0-9]+' $remote_rpm_folder)
    set remote_krnl_rpm_sha (ssh $remote_user@$remote_host sha512sum $remote_krnl_rpm | string split -f 1 ' ')

    set cached_krnl_rpm $kernel_folder/rpm/(path basename $remote_krnl_rpm)
    if test -e $cached_krnl_rpm; and test (sha512sum $cached_krnl_rpm | string split -f 1 ' ') = "$remote_krnl_rpm_sha"
        print_green "$remote_krnl_rpm already downloaded @ $cached_krnl_rpm"
    else
        scp $remote_user@$remote_host:$remote_krnl_rpm (path dirname $cached_krnl_rpm)
        or return
    end
end
