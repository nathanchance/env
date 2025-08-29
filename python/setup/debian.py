#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
import getpass
from pathlib import Path
import shutil
import sys
from tempfile import NamedTemporaryFile

import deb

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
import lib.utils
# pylint: enable=wrong-import-position


def get_version_id():
    return int(lib.setup.get_os_rel_val('VERSION_ID'))


def machine_is_trusted():
    return False  # none at the moment but maybe in the future?


def parse_arguments():
    parser = ArgumentParser(description='Set up a Debian installation')

    parser.add_argument('-r', '--root-password', help='Root password')

    return parser.parse_args()


def prechecks():
    lib.utils.check_root()

    supported_versions = (
        'bullseye',
        'bookworm',
        'trixie',
    )
    if (codename := lib.setup.get_version_codename()) not in supported_versions:
        raise RuntimeError(f"Debian {codename} is not supported by this script!")


def setup_repos():
    apt_gpg = Path('/etc/apt/keyrings')
    apt_sources = Path('/etc/apt/sources.list.d')
    codename = lib.setup.get_version_codename()
    version_id = get_version_id()
    dpkg_arch = deb.get_dpkg_arch()

    # Docker
    if version_id < 12:  # bullseye and earlier, bookworm's podman is not ancient
        docker_repo_url = 'https://download.docker.com/linux/debian'
        docker_gpg_key = Path(apt_gpg, 'docker.gpg')
        docker_sources_txt = f"""\
Types: deb
URIs: {docker_repo_url}
Suites: {codename}
Components: stable
Signed-By: {docker_gpg_key}
Architectures: {dpkg_arch}
"""
        lib.setup.fetch_gpg_key(f"{docker_repo_url}/gpg", docker_gpg_key)
        Path(apt_sources, 'docker.sources').write_text(docker_sources_txt, encoding='utf-8')

    # fish
    # only x86_64 is supported in Debian_13 right now?
    fish_deb_ver = 'Debian_12' if version_id == 13 and dpkg_arch != 'amd64' else f"Debian_{version_id}"
    fish_repo_url = 'https://download.opensuse.org/repositories'
    fish_gpg_key = Path(apt_gpg, 'shells_fish.gpg')
    fish_sources_txt = f"""\
Types: deb
URIs: {fish_repo_url.replace('https', 'http')}/shells:/fish/{fish_deb_ver}/
Suites: /
Components:
Signed-By: {fish_gpg_key}
"""
    lib.setup.fetch_gpg_key(f"{fish_repo_url}/shells:fish/{fish_deb_ver}/Release.key", fish_gpg_key)
    Path(apt_sources, 'shells:fish.sources').write_text(fish_sources_txt, encoding='utf-8')

    # gh
    gh_packages = 'https://cli.github.com/packages'
    gh_gpg_key = Path(apt_gpg, 'githubcli-archive-keyring.gpg')
    gh_sources_txt = f"""\
Types: deb
URIs: {gh_packages}
Suites: stable
Components: main
Signed-By: {gh_gpg_key}
Architectures: {dpkg_arch}
"""
    lib.setup.fetch_gpg_key(f"{gh_packages}/{gh_gpg_key.name}", gh_gpg_key)
    Path(apt_sources, 'github-cli.sources').write_text(gh_sources_txt, encoding='utf-8')

    # Tailscale
    if machine_is_trusted():
        tailscale_packages = 'https://pkgs.tailscale.com/stable/debian'
        tailscale_gpg_key = Path(apt_gpg, 'tailscale-archive-keyring.gpg')
        tailscale_sources_txt = f"""\
Types: deb
URIs: {tailscale_packages}
Suites: {codename}
Components: main
Signed-By: {tailscale_gpg_key}
"""
        lib.setup.fetch_gpg_key(f"{tailscale_packages}/{codename}.noarmor.gpg", tailscale_gpg_key)
        Path(apt_sources, 'tailscale.sources').write_text(tailscale_sources_txt, encoding='utf-8')


def update_and_install_packages():
    packages = []
    if machine_is_trusted():
        packages += ['iptables', 'tailscale']
    if get_version_id() >= 13:
        # This is only in bookworm backports
        packages.append('distribution-gpg-keys')

    deb.update_and_install_packages(packages)

    if 'distribution-gpg-keys' not in packages:
        with NamedTemporaryFile() as tmppkg:
            url = 'http://ftp.us.debian.org/debian/pool/main/d/distribution-gpg-keys/distribution-gpg-keys_1.106+ds-1~bpo12+1_all.deb'
            lib.utils.curl(url, tmppkg.name)

            lib.utils.run(['dpkg', '-i', tmppkg.name])


if __name__ == '__main__':
    args = parse_arguments()
    if not (root_password := args.root_password):
        root_password = getpass.getpass(prompt='Password for Debian root account: ')
    user = lib.setup.get_user()

    prechecks()
    deb.set_apt_variables()
    deb.install_initial_packages()
    setup_repos()
    update_and_install_packages()
    lib.setup.chsh_fish(user)
    lib.setup.add_user_to_group_if_exists('kvm', user)
    deb.setup_doas(user, root_password)
    if shutil.which('docker'):
        deb.setup_docker(user)
    else:
        lib.setup.podman_setup(user)
    deb.setup_libvirt(user)
    deb.setup_locales()
    lib.setup.clone_env(user)
    lib.setup.set_date_time()
    lib.setup.setup_initial_fish_config(user)
    lib.setup.setup_ssh_authorized_keys(user)
    lib.setup.setup_virtiofs_automount()
