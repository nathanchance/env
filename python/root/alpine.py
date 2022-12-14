#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

from argparse import ArgumentParser
from pathlib import Path
import re
import shutil
import subprocess
import time

import lib_root


def parse_arguments():
    parser = ArgumentParser(description='Set up an Alpine installation')

    parser.add_argument('-n',
                        '--user-name',
                        default=lib_root.get_user(),
                        help='Name of user account')
    parser.add_argument('-p', '--user-password', help='Password for user account', required=True)

    return parser.parse_args()


def enable_community_repo():
    repo_conf = Path('/etc/apk/repositories')
    repo_txt = repo_conf.read_text(encoding='utf-8')

    # Get the repository URL to create the community repo from (build from the
    # first uncommented line ending in main).
    if not (repo_url := re.search('^([^#].*/)main$', repo_txt, flags=re.M).groups()[0]):
        raise Exception(f"Could not find main repo in {repo_conf}?")
    community_repo = repo_url + 'community'

    # If the community repo is already enabled (uncommented), we do not need to
    # do anything.
    if (match := re.search(f"^#{community_repo}$", repo_txt, flags=re.M)):
        repo_conf.write_text(re.sub(match.group(0), community_repo, repo_txt), encoding='utf-8')


def update_and_install_packages():
    packages = [
        # Development
        'autoconf',
        'automake',
        'distrobox',
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
        'neofetch',
        'stow',
        'tmux',
        'vim',
        'zoxide',

        # git
        'delta',
        'git',

        # Nicer GNU utilities
        'bat',
        'exa',
        'fd',
        'ripgrep',

        # System management
        'btop',
        'doas',
    ]
    lib_root.apk(['update'])
    lib_root.apk(['upgrade'])
    lib_root.apk(['add', *packages])


def setup_user(user_name, user_password):
    if not lib_root.user_exists(user_name):
        useradd_cmd = [
            'adduser',
            '--disabled-password',
            '--gecos', 'Nathan Chancellor',
            '--shell', shutil.which('fish'),
            user_name
        ]  # yapf: disable
        subprocess.run(useradd_cmd, check=True)
        lib_root.chpasswd(user_name, user_password)

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
            subprocess.run(['addgroup', user_name, group], check=True)

    # Setup doas
    doas_conf = Path('/etc/doas.d/doas.conf')
    doas_wheel = 'permit persist :wheel'
    if not re.search(doas_wheel, doas_conf.read_text(encoding='utf-8')):
        with open(doas_conf, 'a', encoding='utf-8') as file:
            file.write(doas_wheel + '\n')

    # Authorize my ssh key
    lib_root.setup_ssh_authorized_keys(user_name)


# https://wiki.alpinelinux.org/wiki/Podman
def setup_podman(user_name):
    # Set up cgroupsv2
    rc_conf = Path('/etc/rc.conf')
    rc_conf_txt = rc_conf.read_text(encoding='utf-8')
    rc_cgroup_mode = 'rc_cgroup_mode="unified"'
    if not re.search(f"^{rc_cgroup_mode}$", rc_conf_txt, flags=re.M):
        rc_cgroup_mode_line = re.search('^#?rc_cgroup_mode=.*$', rc_conf_txt, flags=re.M).group(0)
        rc_conf.write_text(re.sub(rc_cgroup_mode_line, rc_cgroup_mode, rc_conf_txt),
                           encoding='utf-8')

    subprocess.run(['rc-update', 'add', 'cgroups'], check=True)
    subprocess.run(['rc-service', 'cgroups', 'start'], check=True)

    etc_modules = Path('/etc/modules')
    if not re.search('tun', etc_modules.read_text(encoding='utf-8')):
        with open(etc_modules, mode='a', encoding='utf-8') as file:
            file.write('tun\n')

    if not (make_root_rshared := Path('/etc/local.d/make_root_rshared.start')).exists():
        subprocess.run(['rc-update', 'add', 'local', 'default'], check=True)
        make_root_rshared.write_text('#!/bin/sh\n\nmount --make-rshared /\n', encoding='utf-8')
        make_root_rshared.chmod(0o755)

    lib_root.podman_setup(user_name)


if __name__ == '__main__':
    args = parse_arguments()

    lib_root.check_root()
    enable_community_repo()
    update_and_install_packages()
    setup_user(args.user_name, args.user_password)
    setup_podman(args.user_name)
    lib_root.setup_sudo_symlink()
    lib_root.setup_initial_fish_config(args.user_name)

    print("[INFO] Powering off machine in 10 seconds, hit Ctrl-C to cancel...")
    time.sleep(10)
    subprocess.run('poweroff', check=True)
