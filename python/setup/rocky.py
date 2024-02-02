#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from pathlib import Path
import sys

import fedora

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
# pylint: enable=wrong-import-position


def get_rocky_version():
    return int(float(lib.setup.get_os_rel_val('VERSION_ID')))


def prechecks():
    lib.setup.check_root()
    rocky_version = get_rocky_version()
    if rocky_version not in (9, ):
        raise RuntimeError(
            f"Rocky {rocky_version} is not tested with this script, add support for it if it works.",
        )


def install_initial_packages():
    lib.setup.dnf(['clean', 'all'])
    lib.setup.dnf(['update', '-y'])
    lib.setup.dnf(['config-manager', '--set-enabled', 'crb'])
    fedora.dnf_install(['dnf-plugins-core', 'epel-release'])


def install_packages():
    packages = [
        # administration
        'mosh',
        'util-linux-user',

        # extracting
        'tar',
        'unzip',
        'zstd',

        # distrobox
        'distrobox',
        'podman',

        # email
        'cyrus-sasl-plain',
        'mutt',

        # env
        'curl',
        'fish',
        'jq',
        'neofetch',
        'python-pip',
        'openssh',
        'stow',
        'tmux',
        'vim',

        # git
        'gh',
        'git',
        'git-email',

        # repo
        'python',

        # tuxmake
        'tuxmake',
    ]  # yapf: disable

    if lib.setup.is_equinix():
        packages += [
            'libvirt',
            'qemu-img',
            'qemu-kvm',
            'virt-install',
        ]

    fedora.dnf_install(packages)

    # Reinstall shadow-utils to properly set capabilities
    # https://github.com/containers/podman/issues/2788
    lib.setup.dnf(['reinstall', '-y', 'shadow-utils'])


def setup_repos():
    fedora.dnf_add_repo('https://cli.github.com/packages/rpm/gh-cli.repo')
    fedora.dnf_add_repo(
        'https://download.opensuse.org/repositories/shells:/fish:/release:/3/CentOS_8/shells:fish:release:3.repo',
    )

    tuxmake_repo_text = ('[tuxmake]\n'
                         'name=tuxmake\n'
                         'type=rpm-md\n'
                         'baseurl=https://tuxmake.org/packages/\n'
                         'gpgcheck=1\n'
                         'gpgkey=https://tuxmake.org/packages/repodata/repomd.xml.key\n'
                         'enabled=1\n')
    Path('/etc/yum.repos.d/tuxmake.repo').write_text(tuxmake_repo_text, encoding='utf-8')


if __name__ == '__main__':
    user = lib.setup.get_user()

    prechecks()
    fedora.resize_rootfs()
    install_initial_packages()
    setup_repos()
    install_packages()
    fedora.setup_libvirt(user)
    fedora.setup_mosh()
    lib.setup.chsh_fish(user)
    lib.setup.clone_env(user)
    lib.setup.setup_initial_fish_config(user)
    lib.setup.setup_ssh_authorized_keys(user)
