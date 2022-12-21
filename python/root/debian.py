#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

from argparse import ArgumentParser
from pathlib import Path
import platform
import re
import subprocess

import lib_deb
import lib_root


def machine_is_pi():
    return lib_root.get_hostname() == 'raspberrypi'


def machine_is_trusted():
    return lib_root.get_hostname() in ('raspberrypi')


def parse_arguments():
    parser = ArgumentParser(description='Set up a Debian installation')

    parser.add_argument('-r', '--root-password', help='Root password', required=True)

    return parser.parse_args()


def pi_setup(user_name):
    if not machine_is_pi():
        return

    subprocess.run(['raspi-config', '--expand-rootfs'], check=True)
    subprocess.run(['raspi-config', 'nonint', 'do_serial', '0'], check=True)

    dhcpcd_conf_txt = (dhcpcd_conf := Path('/etc/dhcpcd.conf')).read_text(encoding='utf-8')
    if not re.search(r'^interface eth0\nstatic ip_address=192\.168', dhcpcd_conf_txt, flags=re.M):
        dhcpcd_conf_txt += (
            '\n'
            'interface eth0\n'
            f"static ip_address=192.168.4.{205 if platform.machine() == 'aarch64' else 199}/24\n"
            'static routers=192.168.4.1\n'
            'static domain_name_servers=8.8.8.8 8.8.4.4 1.1.1.1 192.168.0.1\n')
        dhcpcd_conf.write_text(dhcpcd_conf_txt, encoding='utf-8')

    ssd_partition = Path('/dev/sda1')
    if ssd_partition.is_block_device():
        mnt_point = Path('/mnt/ssd')
        fstab = Path('/etc/fstab')

        mnt_point.mkdir(exist_ok=True, parents=True)
        lib_root.chown(user_name, mnt_point)

        fstab_text = fstab.read_text(encoding='utf-8')
        if not re.search(str(mnt_point), fstab_text):
            partuuid = subprocess.run(['blkid', '-o', 'value', '-s', 'PARTUUID', ssd_partition],
                                      capture_output=True,
                                      check=True,
                                      text=True).stdout.strip()

            fstab_line = f"PARTUUID={partuuid}\t{mnt_point}\text4\tdefaults,noatime\t0\t1\n"

            fstab.write_text(fstab_text + fstab_line, encoding='utf-8')

        docker_json = Path('/etc/docker/daemon.json')
        docker_json.parent.mkdir(exist_ok=True, parents=True)
        docker_json_txt = ('{\n'
                           f'"data-root": "{mnt_point}/docker"'
                           '\n}\n')
        docker_json.write_text(docker_json_txt, encoding='utf-8')

    x11_opts = Path('/etc/X11/Xsession.options')
    x11_opts_txt = x11_opts.read_text(encoding='utf-8')
    if re.search('^use-ssh-agent$', x11_opts_txt, flags=re.M):
        x11_opts_txt = re.sub('use-ssh-agent', '# use-ssh-agent', x11_opts_txt)
        x11_opts.write_text(x11_opts_txt, encoding='utf-8')


def prechecks():
    lib_root.check_root()

    codename = lib_root.get_version_codename()
    if codename not in ('bullseye'):
        raise Exception(f"Debian {codename} is not supported by this script!")


def setup_repos():
    apt_gpg = Path('/etc/apt/trusted.gpg.d')
    apt_sources = Path('/etc/apt/sources.list.d')
    codename = lib_root.get_version_codename()
    version_id = lib_root.get_os_rel_val('VERSION_ID')
    dpkg_arch = lib_deb.get_dpkg_arch()

    # Docker
    docker_gpg_key = apt_gpg.joinpath('docker.gpg')
    lib_root.fetch_gpg_key('https://download.docker.com/linux/debian/gpg', docker_gpg_key)
    docker_repo = apt_sources.joinpath('docker.list')
    docker_repo.write_text(
        f"deb [arch={dpkg_arch} signed-by={docker_gpg_key}] https://download.docker.com/linux/debian {codename} stable\n",
        encoding='utf-8')

    # fish
    fish_repo_url = 'https://download.opensuse.org/repositories'
    fish_gpg_key = apt_gpg.joinpath('shells_fish_release_3.gpg')
    lib_root.fetch_gpg_key(f"{fish_repo_url}/shells:fish:release:3/Debian_{version_id}/Release.key",
                           fish_gpg_key)
    fish_repo = apt_sources.joinpath('shells:fish:release:3.list')
    fish_repo.write_text(
        f"deb {fish_repo_url.replace('https', 'http')}/shells:/fish:/release:/3/Debian_{version_id}/ /\n",
        encoding='utf-8')

    # gh
    gh_packages = 'https://cli.github.com/packages'
    gh_gpg_key = apt_gpg.joinpath('githubcli-archive-keyring.gpg')
    lib_root.fetch_gpg_key(f"{gh_packages}/{gh_gpg_key.name}", gh_gpg_key)
    gh_repo = apt_sources.joinpath('github-cli.list')
    gh_repo.write_text(f"deb [arch={dpkg_arch} signed-by={gh_gpg_key}] {gh_packages} stable main\n",
                       encoding='utf-8')

    # Tailscale
    if machine_is_trusted():
        if machine_is_pi():
            distro = 'raspbian'
        else:
            distro = 'debian'
        base_tailscale_url = f"https://pkgs.tailscale.com/stable/{distro}/{codename}"
        tailscale_gpg_key = Path('/usr/share/keyrings/tailscale-archive-keyring.gpg')
        lib_root.fetch_gpg_key(f"{base_tailscale_url}.noarmor.gpg", tailscale_gpg_key)
        tailscale_repo = apt_sources.joinpath('tailscale.list')
        tailscale_repo_txt = lib_root.curl([f"{base_tailscale_url}.tailscale-keyring.list"])
        tailscale_repo.write_bytes(tailscale_repo_txt)


def update_and_install_packages():
    packages = []
    if machine_is_trusted():
        packages += ['tailscale']

    lib_deb.update_and_install_packages(packages)


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
    pi_setup(user)
    lib_deb.setup_doas(user, args.root_password)
    lib_deb.setup_docker(user)
    lib_deb.setup_libvirt(user)
    lib_deb.setup_locales()
    lib_root.clone_env(user)
    lib_root.set_date_time()
    lib_root.setup_initial_fish_config(user)
    lib_root.setup_ssh_authorized_keys(user)
