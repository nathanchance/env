#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
import getpass
from pathlib import Path
import platform
import re
import shutil
import sys

import deb

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
import lib.utils
# pylint: enable=wrong-import-position


def machine_is_trusted():
    return lib.setup.get_hostname() in ('raspberrypi')


def parse_arguments():
    parser = ArgumentParser(description='Set up a Debian installation')

    parser.add_argument('-r', '--root-password', help='Root password')

    return parser.parse_args()


def pi_setup(user_name):
    if not lib.setup.is_pi():
        return

    lib.utils.run(['raspi-config', '--expand-rootfs'])
    lib.utils.run(['raspi-config', 'nonint', 'do_serial', '0'])

    ip_addr = f"192.168.4.{205 if platform.machine() == 'aarch64' else 199}"
    dhcpcd_conf, dhcpcd_conf_txt = lib.utils.path_and_text('/etc/dhcpcd.conf')
    # Bullseye and older use dhcpcd
    if dhcpcd_conf_txt:
        if not re.search(
                r'^interface eth0\nstatic ip_address=192\.168', dhcpcd_conf_txt, flags=re.M):
            dhcpcd_conf_txt += ('\n'
                                'interface eth0\n'
                                f"static ip_address={ip_addr}/24\n"
                                'static routers=192.168.4.1\n'
                                'static domain_name_servers=8.8.8.8 8.8.4.4 1.1.1.1 192.168.0.1\n')
            dhcpcd_conf.write_text(dhcpcd_conf_txt, encoding='utf-8')
    # Bookworm and newer use NetworkManager
    else:
        lib.setup.setup_static_ip(ip_addr)

    lib.setup.setup_mnt_ssd(user_name)

    x11_opts, x11_opts_txt = lib.utils.path_and_text('/etc/X11/Xsession.options')
    if x11_opts_txt:
        conf = 'use-ssh-agent'
        if re.search(f"^{conf}$", x11_opts_txt, flags=re.M):
            x11_opts.write_text(x11_opts_txt.replace(conf, f"# {conf}"), encoding='utf-8')


def prechecks():
    lib.setup.check_root()

    supported_versions = (
        'bullseye',
        'bookworm',
    )
    if (codename := lib.setup.get_version_codename()) not in supported_versions:
        raise RuntimeError(f"Debian {codename} is not supported by this script!")


def setup_repos():
    apt_gpg = Path('/etc/apt/trusted.gpg.d')
    apt_sources = Path('/etc/apt/sources.list.d')
    codename = lib.setup.get_version_codename()
    version_id = lib.setup.get_os_rel_val('VERSION_ID')
    dpkg_arch = deb.get_dpkg_arch()

    # Docker
    if int(version_id) < 12:  # bullseye and earlier, bookworm's podman is not ancient
        docker_gpg_key = Path(apt_gpg, 'docker.gpg')
        lib.setup.fetch_gpg_key('https://download.docker.com/linux/debian/gpg', docker_gpg_key)
        Path(apt_sources, 'docker.list').write_text(
            f"deb [arch={dpkg_arch} signed-by={docker_gpg_key}] https://download.docker.com/linux/debian {codename} stable\n",
            encoding='utf-8')

    # fish
    fish_repo_url = 'https://download.opensuse.org/repositories'
    lib.setup.fetch_gpg_key(f"{fish_repo_url}/shells:fish/Debian_{version_id}/Release.key",
                            Path(apt_gpg, 'shells_fish.gpg'))
    Path(apt_sources, 'shells:fish.list').write_text(
        f"deb {fish_repo_url.replace('https', 'http')}/shells:/fish/Debian_{version_id}/ /\n",
        encoding='utf-8')

    # gh
    gh_packages = 'https://cli.github.com/packages'
    gh_gpg_key = Path(apt_gpg, 'githubcli-archive-keyring.gpg')
    lib.setup.fetch_gpg_key(f"{gh_packages}/{gh_gpg_key.name}", gh_gpg_key)
    Path(apt_sources, 'github-cli.list').write_text(
        f"deb [arch={dpkg_arch} signed-by={gh_gpg_key}] {gh_packages} stable main\n",
        encoding='utf-8')

    # Tailscale
    if machine_is_trusted():
        distro = 'raspbian' if lib.setup.is_pi() else 'debian'
        base_tailscale_url = f"https://pkgs.tailscale.com/stable/{distro}/{codename}"

        tailscale_gpg_key = Path('/usr/share/keyrings/tailscale-archive-keyring.gpg')
        lib.setup.fetch_gpg_key(f"{base_tailscale_url}.noarmor.gpg", tailscale_gpg_key)

        tailscale_repo_txt = lib.utils.curl(f"{base_tailscale_url}.tailscale-keyring.list")
        Path(apt_sources, 'tailscale.list').write_bytes(tailscale_repo_txt)


def update_and_install_packages():
    packages = []
    if machine_is_trusted():
        packages += ['iptables', 'tailscale']

    deb.update_and_install_packages(packages)


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
    pi_setup(user)
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
