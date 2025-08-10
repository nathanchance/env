#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function prep_pkg_for_vm -d "Prepare package building files for virtual machine build"
    set package $argv[1]
    if test -z "$package"
        read -P 'Package to build: ' package
    end

    set arch (uname -m)
    set vm $argv[2]
    if test -z "$vm"
        print_warning "No virtual machine, assuming default for $arch..."
        switch $arch
            case aarch64
                set vm fedora
            case x86_64
                set vm arch
        end
    end

    if string match -qr arch $vm
        set package_dirs $ENV_FOLDER/pkgbuilds/$package $SRC_FOLDER/packaging/pkg/$package
    end
    if string match -qr fedora $vm
        set package_dirs $ENV_FOLDER/specs/$package $SRC_FOLDER/packaging/rpm/$package
    end
    for item in $package_dirs
        if test -d $item
            set src_dir $item
        end
    end
    if not set -q src_dir
        print_error "Could not find source for package '$package' in possible locations '$package_dirs'!"
        return 1
    end

    set dst_dir $VM_FOLDER/$arch/$vm/shared/$package

    if test -e $src_dir/.git
        remkdir $dst_dir
        echo "Copying $src_dir to $dst_dir via 'git archive'..."
        git -C $src_dir archive --format=tar HEAD | tar -C $dst_dir -vxf -
    else
        rm -fr $dst_dir
        mkdir -p (path dirname $dst_dir)
        cp -rv $src_dir (path dirname $dst_dir)
    end
end
