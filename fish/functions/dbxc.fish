#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function dbxc -d "Shorthand for 'distrobox create'"
    in_container_msg -h; or return

    set add_args --pids-limit=-1

    set i 1
    while test $i -le (count $argv)
        set arg $argv[$i]
        switch $arg
            case -e --env -v
                set next (math $i + 1)
                set -a add_args $arg $argv[$next]
                set i $next

            case -s --skip-cbl
                set skip_cbl true

            case --ephemeral
                set mode ephemeral

            case --env='*' --volume='*'
                set -a add_args $arg

            case --root -Y --yes
                set -a dbx_args $arg

            case --volume
                set next (math $i + 1)
                set -a dbx_args $arg $argv[$next]
                set i $next

            case dev/'*'
                set img $GHCR/$arg
                set name (string replace / - $arg)

            case dev-'*'
                set img $GHCR/(string replace - / $arg)
                set name $arg

            case '*'
                set -a dbx_cmds $arg
        end
        set i (math $i + 1)
    end

    # If not in ephemeral mode, use 'distrobox create'
    if not set -q mode
        set mode create
    end

    # If no image was specified, default to the one for the architecture
    if not set -q img
        set img (dev_img_gh)
        set name (dev_img)
    end

    set -a dbx_args -i $img
    if test "$mode" = create
        set -a dbx_args -n $name
        if dbx create --help &| grep -q -- --no-entry
            set -a dbx_args --no-entry
        end
    end
    if in_orb
        set -a dbx_args --volume $MAC_FOLDER:$MAC_FOLDER
        # OrbStack has passwordless sudo, we don't need to bother with a password in distrobox
        set -a dbx_args --absolutely-disable-root-password-i-am-really-positively-sure
    end
    if test -d $OPT_ORB_GUEST
        set -a dbx_args --volume $OPT_ORB_GUEST:$OPT_ORB_GUEST
    end

    # If we are using a development image AND it is the default one for our
    # architecture (to avoid weird dynamic linking failures), use the binaries
    # in $CBL by default
    if test "$img" = (dev_img_gh); and not set -q skip_cbl
        set -a add_args --env=USE_CBL=1
    end

    # If we are going to use an Arch Linux container and the host is using
    # Reflector to update the mirrorlist, mount the mirrorlist into the
    # container so it can enjoy quick updates
    if test "$img" = $GHCR/dev/arch; and test -f /etc/xdg/reflector/reflector.conf
        set -a add_args --volume=/etc/pacman.d/mirrorlist:/etc/pacman.d/mirrorlist:ro
    end

    set dbx_init_hooks $HOME/.local/share/distrobox/init-hooks
    mkdir -p $dbx_init_hooks

    if test "$mode" = create
        set init_hook_sh $dbx_init_hooks/$name.sh
        # to ensure chmod succeeds
        touch $init_hook_sh
    else
        set init_hook_sh (mktemp -p $dbx_init_hooks --suffix=.sh)
    end

    chmod +x $init_hook_sh
    echo '#!/bin/sh

user="'"$USER"'"

if ! grep -q "$user" /etc/doas.conf 2>/dev/null; then
    echo "permit nopass $user as root" >>/etc/doas.conf
fi

# Unconditionally calling host-spawn is not acceptable in my environment
# Should a use for a graphical distrobox container be discovered later,
# a different compatible passthrough scheme can be created at that point.
if grep -q host-spawn /etc/fish/conf.d/distrobox_config.fish; then
    sed -i /host-spawn/d /etc/fish/conf.d/distrobox_config.fish
fi' >$init_hook_sh

    if is_hetzner
        add_hetzner_mirror_to_repos -p >>$init_hook_sh
    end

    # If we are using docker, we need to explicitly set the container's
    # kvm group to the same group ID as the host's kvm group if it exists
    # so that accelerated VMs work within a container. Do this with an init hook.
    if command -q docker; and group_exists kvm
        set -l host_kvm_gid (getent group kvm | string split -f 3 :)

        echo '
target_gid="'"$host_kvm_gid"'"

group() {
    getent group "$@"
}

group_quiet() {
    group "$@" >/dev/null 2>&1
}

group_get_field() {
    group "${@:2}" | cut -d : -f "$1"
}

kvm_group_exists() {
    group_quiet kvm
}

kvm_gid() {
    kvm_group_exists || return
    group_to_gid kvm
}

target_gid_exists() {
    group_quiet "$target_gid"
}

gid_to_group() {
    group_get_field 1 "$@"
}

group_to_gid() {
    group_get_field 3 "$@"
}

user_in_target_gid() {
    target_gid_exists || return
    group "$target_gid" | grep -qw "$user"
}

kvm_gid_mismatch() {
    [ "$(kvm_gid)" != "$target_gid" ]
}

if ! user_in_target_gid; then
    if target_gid_exists; then
        group=$(gid_to_group "$target_gid")
    else
        group=kvm
        if kvm_gid_mismatch; then
            kvm_group_exists && groupdel -f "$group"
            groupadd -g "$target_gid" "$group" || exit
        fi
    fi
    usermod -aG "$group" "$user" || exit
fi' >>$init_hook_sh
    end

    if test "$mode" = ephemeral
        printf '\nrm "%s"\n' $init_hook_sh >>$init_hook_sh
    end

    if set -q init_hook_sh
        set -p dbx_args --init-hooks $init_hook_sh
    end

    if test "$mode" = create
        set -p dbx_args -a "$add_args"
    else
        set -p dbx_args '-a "'$add_args'"'
    end

    set final_dbx_cmd dbx $mode $dbx_args $dbx_img $dbx_cmds
    print_cmd $final_dbx_cmd
    $final_dbx_cmd
end
