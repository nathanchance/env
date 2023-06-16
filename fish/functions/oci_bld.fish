#
#/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function oci_bld -d "Build an OCI container image"
    in_container_msg -h; or return

    for mgr in podman docker none
        if command -q $mgr
            break
        end
    end

    switch $mgr
        case docker
            set mgr_args \
                --no-cache
        case podman
            set mgr_args \
                --layers=false
        case none
            print_warning "oci_bld requires podman or docker, skipping..."
            return 0
    end

    if set -q GITHUB_TOKEN
        set mgr_args \
            --build-arg=GITHUB_TOKEN=$GITHUB_TOKEN
    end

    for arg in $argv
        switch $arg
            case dev dev/{alpine,arch,debian,fedora,suse,ubuntu}
                set -a images $arg
        end
    end

    for image in $images
        switch $image
            case dev
                set folder (get_dev_img)
                set image $folder

            case '*'
                set folder $image
        end

        pushd $ENV_FOLDER/podman/$folder; or return

        set mgr_build_cmd \
            $mgr build \
            $mgr_args \
            --pull \
            --tag $GHCR/$image .
        print_cmd $mgr_build_cmd
        $mgr_build_cmd; or return

        popd; or return
    end
end
