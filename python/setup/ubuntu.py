#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
import getpass
from pathlib import Path
import sys

import deb

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
# pylint: enable=wrong-import-position


def apt_add_repo(repo_to_add):
    lib.utils.run(['apt-add-repository', '-y', repo_to_add])


def parse_arguments():
    parser = ArgumentParser(description='Set up an Ubuntu installation')

    parser.add_argument('-r', '--root-password', help='Root password')

    return parser.parse_args()


def prechecks():
    lib.utils.check_root()

    supported_versions = ('focal', 'jammy', 'kinetic')
    if (codename := lib.setup.get_version_codename()) not in supported_versions:
        raise RuntimeError(f"Ubuntu {codename} is not supported by this script!")


def setup_repos():
    apt_gpg = Path('/etc/apt/trusted.gpg.d')
    apt_sources = Path('/etc/apt/sources.list.d')
    codename = lib.setup.get_version_codename()
    dpkg_arch = deb.get_dpkg_arch()

    # Docker
    docker_gpg_key = Path(apt_gpg, 'docker.gpg')
    lib.setup.fetch_gpg_key('https://download.docker.com/linux/ubuntu/gpg', docker_gpg_key)
    Path(apt_sources, 'docker.list').write_text(
        f"deb [arch={dpkg_arch} signed-by={docker_gpg_key}] https://download.docker.com/linux/ubuntu {codename} stable\n",
        encoding='utf-8')

    # fish
    apt_add_repo('ppa:fish-shell/release-3')

    # gh
    gh_packages = 'https://cli.github.com/packages'
    gh_gpg_key = Path(apt_gpg, 'githubcli-archive-keyring.gpg')
    lib.setup.fetch_gpg_key(f"{gh_packages}/{gh_gpg_key.name}", gh_gpg_key)
    Path(apt_sources, 'github-cli.list').write_text(
        f"deb [arch={dpkg_arch} signed-by={gh_gpg_key}] {gh_packages} stable main\n",
        encoding='utf-8')

    # git
    apt_add_repo('ppa:git-core/ppa')


if __name__ == '__main__':
    args = parse_arguments()
    if not (root_password := args.root_password):
        root_password = getpass.getpass(prompt='Password for Ubuntu root account: ')
    user = lib.setup.get_user()

    prechecks()
    deb.set_apt_variables()
    deb.install_initial_packages()
    setup_repos()
    deb.update_and_install_packages()
    lib.setup.chsh_fish(user)
    lib.setup.add_user_to_group_if_exists('kvm', user)
    deb.setup_doas(user, root_password)
    deb.setup_docker(user)
    deb.setup_libvirt(user)
    deb.setup_locales()
    lib.setup.clone_env(user)
    lib.setup.set_date_time()
    lib.setup.setup_initial_fish_config(user)
    lib.setup.setup_ssh_authorized_keys(user)
