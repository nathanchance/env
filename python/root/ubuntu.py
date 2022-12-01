#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

import argparse
import pathlib
import subprocess

import deb
import lib


def apt_add_repo(repo_to_add):
    subprocess.run(['apt-add-repository', '-y', repo_to_add], check=True)


def parse_arguments():
    parser = argparse.ArgumentParser(description='Set up an Ubuntu installation')

    parser.add_argument('-r', '--root-password', help='Root password', required=True)

    return parser.parse_args()


def prechecks():
    lib.check_root()

    codename = lib.get_version_codename()
    if codename not in ('focal', 'jammy', 'kinetic'):
        raise Exception(f"Ubuntu {codename} is not supported by this script!")


def setup_repos():
    apt_gpg = pathlib.Path('/etc/apt/trusted.gpg.d')
    apt_sources = pathlib.Path('/etc/apt/sources.list.d')
    codename = lib.get_version_codename()
    dpkg_arch = deb.get_dpkg_arch()

    # Docker
    docker_gpg_key = apt_gpg.joinpath('docker.gpg')
    lib.fetch_gpg_key('https://download.docker.com/linux/ubuntu/gpg', docker_gpg_key)
    docker_repo = apt_sources.joinpath('docker.list')
    docker_repo.write_text(
        f"deb [arch={dpkg_arch} signed-by={docker_gpg_key}] https://download.docker.com/linux/ubuntu {codename} stable\n",
        encoding='utf-8')

    # fish
    apt_add_repo('ppa:fish-shell/release-3')

    # gh
    gh_packages = 'https://cli.github.com/packages'
    gh_gpg_key = apt_gpg.joinpath('githubcli-archive-keyring.gpg')
    lib.fetch_gpg_key(f"{gh_packages}/{gh_gpg_key.name}", gh_gpg_key)
    gh_repo = apt_sources.joinpath('github-cli.list')
    gh_repo.write_text(f"deb [arch={dpkg_arch} signed-by={gh_gpg_key}] {gh_packages} stable main\n",
                       encoding='utf-8')

    # git
    apt_add_repo('ppa:git-core/ppa')


if __name__ == '__main__':
    args = parse_arguments()
    user = lib.get_user()

    prechecks()
    deb.set_apt_variables()
    deb.install_initial_packages()
    setup_repos()
    deb.update_and_install_packages()
    lib.chsh_fish(user)
    lib.add_user_to_group_if_exists('kvm', user)
    deb.setup_doas(user, args.root_password)
    deb.setup_docker(user)
    deb.setup_libvirt(user)
    deb.setup_locales()
    lib.clone_env(user)
    lib.set_date_time()
    lib.setup_initial_fish_config(user)
