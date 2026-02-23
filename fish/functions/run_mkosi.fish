#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function run_mkosi -d "Run mkosi with various arguments"
    # Handle initial arguments
    switch (count $argv)
        case 0
            set verb build
            set image $DEV_IMG
        case 1
            set verb $argv[1]
            set image $DEV_IMG
        case '*'
            set verb $argv[1]
            set image $argv[2]
            set mkosi_user_args $argv[3..]
    end

    # Validate verb argument
    switch $verb
        case build ssh summary vm
        case '*'
            __print_error "Unhandled verb: $verb"
            return 1
    end

    # dev-* images share a single directory, switching on '--distribution'
    if string match -qr ^dev- $image
        set distro (string split -f 2 - $image)
        if not contains -- --distribution $mkosi_user_args; and not contains -- -d $mkosi_user_args
            set -a mkosi_args --distribution $distro
        end
        set image dev
    end

    # Validate mkosi.conf exists
    set env_mkosi $ENV_FOLDER/mkosi
    if string match -qr ^/ $image # absolute path
        set directory $image
    else
        set directory $env_mkosi/$image
    end
    set mkosi_conf $directory/mkosi.conf
    if not test -e $mkosi_conf
        __print_error "No build files for $image?"
        return 1
    end

    # Download source code to use resources without consistent virtual environment
    set mkosi_src $SRC_FOLDER/run_mkosi
    if test -d $mkosi_src
        set mkosi_src_old_sha (git -C $mkosi_src sha @{u})
        git -C $mkosi_src urh &>/dev/null
        set mkosi_src_new_sha (git -C $mkosi_src sha @{u})
    else
        mkdir -p (path dirname $mkosi_src)
        git clone https://github.com/systemd/mkosi $mkosi_src
        or return
        set mkosi_fresh_clone true
    end

    # Use a different uv prefix for root commands
    set uv_default_root_dst $XDG_FOLDER/uv/run_mkosi
    set uv_default_root_env_cmd \
        env \
        UV_CACHE_DIR=$uv_default_root_dst/cache \
        UV_PYTHON_BIN_DIR=$uv_default_root_dst/bin \
        UV_PYTHON_CACHE_DIR=$uv_default_root_dst/cache \
        UV_PYTHON_INSTALL_DIR=$uv_default_root_dst/python \
        UV_TOOL_BIN_DIR=$uv_default_root_dst/bin \
        UV_TOOL_DIR=$uv_default_root_dst/tools
    # pgo-llvm-builder requires a patched mkosi because it is based on Debian Buster
    if test (path basename $directory) = pgo-llvm-builder
        set uv_proj_user_dst $XDG_FOLDER/uv/$USER/pgo-llvm-builder
        set uv_proj_root_dst $uv_default_root_dst/pgo-llvm-builder

        set uv_user_env_cmd (string replace $uv_default_root_dst $uv_proj_user_dst $uv_default_root_env_cmd)
        set uv_root_env_cmd (string replace $uv_default_root_dst $uv_proj_root_dst $uv_default_root_env_cmd)

        if set -q mkosi_fresh_clone
            or test $mkosi_src_old_sha != $mkosi_src_new_sha
            or not test -x $uv_root_dst/bin/mkosi
            or not test -x $uv_user_dst/bin/mkosi
            set install_mkosi true
        end

        if set -q install_mkosi
            begin
                sed -i \
                    -e "s;suite=f\"{context.config.release}-security\";suite=f\"{context.config.release}{'/updates' if context.config.release == 'buster' else '-security'}\";g" \
                    -e "s;install_apt_sources(context, cls.repositories(context, for_image=True));install_apt_sources(context, cls.repositories(context));g" \
                    $mkosi_src/mkosi/distribution/debian.py
                and git -C $mkosi_src --no-pager diff HEAD
                and $uv_user_env_cmd uv tool install --reinstall $mkosi_src
                and $uv_root_env_cmd uv tool install --reinstall $mkosi_src
                and git -C $mkosi_src reset --hard
            end
            or return
        end
    else
        # user uses default environment values
        set uv_root_env_cmd $uv_default_root_env_cmd
        set uvx_args \
            # not available on pypi
            --from git+https://github.com/systemd/mkosi.git
    end
    set mkosi_user \
        $uv_user_env_cmd \
        uvx $uvx_args \
        mkosi
    set mkosi_root \
        run0 \
        $uv_root_env_cmd \
        # 'command -v' as uvx may not be in root's PATH
        (command -v uvx) $uvx_args \
        mkosi

    # ensure mkosi does not create root folders initially, as that might mess with permissions
    mkdir -p (string match -er = $uv_root_env_cmd | string split -f 2 =)

    # Sources to mount for the build process
    set build_sources \
        # We may need to use custom functions from our Python framework
        $PYTHON_FOLDER:/python \
        # We may need to look at the configuration of the host
        /etc:/etc

    # Cache package downloads
    set mkosi_cache $XDG_FOLDER/cache/mkosi
    if not test -d $mkosi_cache
        mkdir -p $mkosi_cache
    end
    switch (path basename $directory)
        case dev
            switch $distro
                case arch
                    set cache_dir pacman
                case debian
                    set cache_dir apt
                case fedora
                    set cache_dir dnf
            end
        case '*'arch'*'
            set cache_dir pacman
        case '*'debian'*'
            set cache_dir apt
        case pgo-llvm-builder
            set cache_dir apt
            set -a mkosi_args --environment PYTHON_PGO_BUILDER_UID=(id -u)
        case '*'fedora'*'
            set cache_dir dnf
        case '*'
            set cache_dir generic
    end

    request_root "Running mkosi"
    or return

    # Use common tools tree based on mkosi default value
    set tools_tree $env_mkosi/tools
    if not test -e $tools_tree/etc/resolv.conf
        $mkosi_root \
            --directory $mkosi_src/mkosi/resources/mkosi-tools \
            --format directory \
            --output (path basename $tools_tree) \
            --output-directory (path dirname $tools_tree) \
            --profile misc,package-manager,runtime
        or return

        run0 chown -R $USER:$USER $tools_tree
        or return
    end

    # Using a bootable profile
    if contains -- bootable $mkosi_user_args
        set bootable true
    end

    # Only truly dynamic arguments (namely from fish variables) should be added here.
    set -a mkosi_args \
        --build-sources (string join , $build_sources) \
        --directory $directory \
        --package-cache-dir $mkosi_cache/$cache_dir \
        --tools-tree $tools_tree \
        $mkosi_user_args
    if test "$verb" = build
        set -a mkosi_args --force
        if test -d $NVME_FOLDER
            set -a mkosi_args --environment NVME_FOLDER=$NVME_FOLDER
        end
    end

    set mkosi_user_cmd \
        $mkosi_user \
        $mkosi_args
    set mkosi_root_cmd \
        $mkosi_root \
        $mkosi_args

    $mkosi_user_cmd summary --json | python3 -c "import json, sys
mkosi_json = json.load(sys.stdin)
for image in mkosi_json['Images']:
    if image['Image'] == 'main':
        image_id = image['ImageId']
        distribution = image['Distribution']
        break
else:
    raise RuntimeError('No main image?')
print(image_id)
print(distribution)" | read -L image_id distribution
    set ret $pipestatus
    if test $ret[2] -ne 0
        __print_error "Error trying to parse output from 'mkosi summary'?"
        return 1
    end

    if set -q bootable
        # Output to $VM_FOLDER/mkosi/<image_id> by default
        if not contains -- --output-directory $mkosi_user_args
            set bootable_output $VM_FOLDER/mkosi/$image_id
            mkdir -p (path dirname $bootable_output)
            set -a mkosi_root_cmd --output-directory $bootable_output
        end
        # Generate keys if they do not exit
        if not test -e $directory/mkosi.crt; or not test -e $directory/mkosi.key
            $mkosi_user_cmd genkey
            or return

            chmod 600 $directory/mkosi.{crt,key}
        end
    end

    # If running Arch on Arch, we need the alpm system user to have the same
    # UID as the one on the host to ensure idmapping works. Do this with a
    # sysusers.d override via a skeleton tree.
    if test (__get_distro) = arch; and test "$distribution" = arch
        if test -e $directory/mkosi.skeleton
            set default_skeleton_dir $directory/mkosi.skeleton
        end
        set src_alpm_conf /usr/lib/sysusers.d/alpm.conf
        set arch_skeleton_dir $directory/mkosi.skeleton.arch
        set dst_alpm_conf $arch_skeleton_dir(string replace /usr/lib /etc $src_alpm_conf)

        # create directory fresh each invocation to ensure it is always up to date
        rm -fr $arch_skeleton_dir
        mkdir -p (path dirname $dst_alpm_conf)
        string replace 'u alpm -' 'u alpm '(id -u alpm) <$src_alpm_conf >$dst_alpm_conf

        set -a mkosi_root_cmd --skeleton-tree (string join , $default_skeleton_dir $arch_skeleton_dir)
    end

    set fish_trace 1
    $mkosi_root_cmd $verb
    or return
    set -e fish_trace

    if test "$verb" = build
        if set -q bootable_output
            run0 chown -R $USER:$USER $bootable_output
        end

        # selinux contexts may get messed up, fix them if necessary
        if test -e /sys/fs/selinux; and test (cat /sys/fs/selinux/enforce) = 1; and not set -q bootable
            set machine_dir /var/lib/machines/$image_id
            __tg_msg "root authorization needed to check SELinux context of $machine_dir"
            set context (run0 stat $machine_dir | string match -gr '^Context: (.*)$')
            if test "$context" != "system_u:object_r:unlabeled_t:s0"; and test "$context" != "system_u:object_r:systemd_machined_var_lib_t:s0"
                __print_warning "$machine_dir context is unexpected ('$context'), running restorcecon..."
                run0 restorecon -R $machine_dir
            end
        end
    end
end
