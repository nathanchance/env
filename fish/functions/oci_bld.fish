#
#/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function oci_bld -d "Build an OCI container image"
    in_container_msg -h; or return

    for mgr in podman docker none
        if command -q $mgr
            break
        end
    end

    switch $mgr
        case docker
            set base_mgr_args \
                --no-cache
        case podman
            set base_mgr_args \
                --layers=false
        case none
            print_warning "oci_bld requires podman or docker, skipping..."
            return 0
    end

    for arg in $argv
        switch $arg
            case compilers
                set -a images \
                    gcc-$GCC_VERSIONS_KERNEL \
                    llvm-$LLVM_VERSIONS_KERNEL \
                    llvm-android

            case dev dev/{alpine,arch,debian,fedora,suse,ubuntu} {gcc,llvm}-'*'
                set -a images $arg
        end
    end

    for image in $images
        set -l mgr_args

        switch $image
            case gcc-5
                set base ubuntu:xenial
            case llvm-12 llvm-11
                set base ubuntu:focal
            case llvm-android
                if test (uname -m) != x86_64
                    print_error "$image cannot be build on non-x86_64 hosts"
                    continue
                end
                set base ubuntu:jammy
            case gcc-'*' llvm-'*'
                set base ubuntu:jammy
        end

        switch $image
            case dev
                set folder (get_dev_img)
                set image $folder

            case {gcc,llvm}-'*'
                set mgr_args \
                    --build-arg BASE=docker.io/$base \
                    --build-arg COMPILER=$image
                set folder compiler

            case '*'
                set folder $image
        end

        pushd $ENV_FOLDER/podman/$folder; or return

        set mgr_build_cmd \
            $mgr build \
            $base_mgr_args \
            $mgr_args \
            --pull \
            --tag $GHCR/$image .
        print_cmd $mgr_build_cmd
        $mgr_build_cmd; or return

        popd; or return
    end
end
