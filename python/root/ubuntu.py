#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

from argparse import ArgumentParser
from pathlib import Path
import subprocess

import lib_deb
import lib_root


def apt_add_repo(repo_to_add):
    subprocess.run(['apt-add-repository', '-y', repo_to_add], check=True)


def parse_arguments():
    parser = ArgumentParser(description='Set up an Ubuntu installation')

    parser.add_argument('-r', '--root-password', help='Root password', required=True)

    return parser.parse_args()


def prechecks():
    lib_root.check_root()

    codename = lib_root.get_version_codename()
    if codename not in ('focal', 'jammy', 'kinetic'):
        raise Exception(f"Ubuntu {codename} is not supported by this script!")


def setup_repos():
    apt_gpg = Path('/etc/apt/trusted.gpg.d')
    apt_sources = Path('/etc/apt/sources.list.d')
    codename = lib_root.get_version_codename()
    dpkg_arch = lib_deb.get_dpkg_arch()

    # Docker
    docker_gpg_key = apt_gpg.joinpath('docker.gpg')
    lib_root.fetch_gpg_key('https://download.docker.com/linux/ubuntu/gpg', docker_gpg_key)
    docker_repo = apt_sources.joinpath('docker.list')
    docker_repo.write_text(
        f"deb [arch={dpkg_arch} signed-by={docker_gpg_key}] https://download.docker.com/linux/ubuntu {codename} stable\n",
        encoding='utf-8')

    # fish
    apt_add_repo('ppa:fish-shell/release-3')

    # gh
    gh_packages = 'https://cli.github.com/packages'
    gh_gpg_key = apt_gpg.joinpath('githubcli-archive-keyring.gpg')
    lib_root.fetch_gpg_key(f"{gh_packages}/{gh_gpg_key.name}", gh_gpg_key)
    gh_repo = apt_sources.joinpath('github-cli.list')
    gh_repo.write_text(f"deb [arch={dpkg_arch} signed-by={gh_gpg_key}] {gh_packages} stable main\n",
                       encoding='utf-8')

    # git
    apt_add_repo('ppa:git-core/ppa')


if __name__ == '__main__':
    args = parse_arguments()
    user = lib_root.get_user()

    prechecks()
    lib_deb.set_apt_variables()
    lib_deb.install_initial_packages()
    setup_repos()
    lib_deb.update_and_install_packages()
    lib_root.chsh_fish(user)
    lib_root.add_user_to_group_if_exists('kvm', user)
    lib_deb.setup_doas(user, args.root_password)
    lib_deb.setup_docker(user)
    lib_deb.setup_libvirt(user)
    lib_deb.setup_locales()
    lib_root.clone_env(user)
    lib_root.set_date_time()
    lib_root.setup_initial_fish_config(user)
    lib_root.setup_ssh_authorized_keys(user)
