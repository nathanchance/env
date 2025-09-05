#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
import getpass
from pathlib import Path
import re
import shutil
import sys
import time

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
import lib.utils
# pylint: enable=wrong-import-position


def parse_arguments():
    parser = ArgumentParser(description='Set up an Alpine installation')

    parser.add_argument('-n',
                        '--user-name',
                        default=lib.setup.get_user(),
                        help='Name of user account')
    parser.add_argument('-p', '--user-password', help='Password for user account')

    return parser.parse_args()


def enable_community_repo():
    conf, text = lib.utils.path_and_text('/etc/apk/repositories')

    # Get the repository URL to create the community repo from (build from the
    # first uncommented line ending in main).
    if not (repo_url := re.search('^([^#].*/)main$', text, flags=re.M).groups()[0]):
        raise RuntimeError(f"Could not find main repo in {conf}?")
    community_repo = repo_url + 'community'

    # If the community repo is already enabled (uncommented), we do not need to
    # do anything.
    if (match := re.search(f"^#{community_repo}$", text, flags=re.M)):
        conf.write_text(text.replace(match.group(0), community_repo), encoding='utf-8')


def update_and_install_packages():
    packages = [
        # Development
        'autoconf',
        'automake',
        'gcc',
        'hyperfine',
        'linux-headers',
        'make',
        'musl-dev',
        'pkgconf',
        'podman',

        # env
        'curl',
        'fish',
        'fzf',
        'jq',
        'stow',
        'tmux',
        'vim',
        'zoxide',

        # git
        'delta',
        'git',

        # Nicer GNU utilities
        'bat',
        'eza',
        'fd',
        'ripgrep',

        # System management
        'btop',
        'doas',
    ]
    lib.setup.apk(['update'])
    lib.setup.apk(['upgrade'])
    lib.setup.apk(['add', *packages])


def setup_user(user_name, user_password):
    if not lib.setup.user_exists(user_name):
        useradd_cmd = [
            'adduser',
            '--disabled-password',
            '--gecos', 'Nathan Chancellor',
            '--shell', shutil.which('fish'),
            user_name,
        ]  # yapf: disable
        lib.utils.run(useradd_cmd)
        lib.setup.chpasswd(user_name, user_password)

        user_groups = [
            # Default setup-alpine
            'audio',
            'netdev',
            'video',
            # Mine
            'kvm',
            'wheel',
        ]
        for group in user_groups:
            lib.utils.run(['addgroup', user_name, group])

    # Setup doas
    doas_conf, doas_text = lib.utils.path_and_text('/etc/doas.d/doas.conf')
    if (doas_wheel := 'permit persist :wheel') not in doas_text:
        doas_conf.write_text(f"{doas_conf}{doas_wheel}\n", encoding='utf-8')

    # Authorize my ssh key
    lib.setup.setup_ssh_authorized_keys(user_name)


# https://wiki.alpinelinux.org/wiki/Podman
def setup_podman(user_name):
    # Set up cgroupsv2
    rc_conf, rc_conf_txt = lib.utils.path_and_text('/etc/rc.conf')
    rc_cgroup_mode = 'rc_cgroup_mode="unified"'
    if not re.search(f"^{rc_cgroup_mode}$", rc_conf_txt, flags=re.M):
        rc_cgroup_mode_line = re.search('^#?rc_cgroup_mode=.*$', rc_conf_txt, flags=re.M).group(0)
        rc_conf.write_text(rc_conf_txt.replace(rc_cgroup_mode_line, rc_cgroup_mode),
                           encoding='utf-8')

    lib.utils.run(['rc-update', 'add', 'cgroups'])
    lib.utils.run(['rc-service', 'cgroups', 'start'])

    modules, modules_text = lib.utils.path_and_text('/etc/modules')
    if 'tun' not in modules_text:
        modules.write_text(f"{modules_text}tun\n", encoding='utf-8')

    if not (make_root_rshared := Path('/etc/local.d/make_root_rshared.start')).exists():
        lib.utils.run(['rc-update', 'add', 'local', 'default'])
        make_root_rshared.write_text('#!/bin/sh\n\nmount --make-rshared /\n', encoding='utf-8')
        make_root_rshared.chmod(0o755)

    lib.setup.podman_setup(user_name)


if __name__ == '__main__':
    args = parse_arguments()
    if not (password := args.user_password):
        password = getpass.getpass(prompt='Password for Alpine user account: ')

    lib.utils.check_root()
    enable_community_repo()
    update_and_install_packages()
    setup_user(args.user_name, password)
    setup_podman(args.user_name)
    lib.setup.setup_sudo_symlink()
    lib.setup.setup_initial_fish_config(args.user_name)

    print("[INFO] Powering off machine in 10 seconds, hit Ctrl-C to cancel...")
    time.sleep(10)
    lib.utils.run('poweroff')
