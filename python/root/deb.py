#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

import os
import pathlib
import subprocess
import shutil
import tempfile

import lib


def apt_install(install_args):
    lib.apt(['install', '-y', '--no-install-recommends'] + install_args)


def apt_update():
    lib.apt(['update', '-qq'])


def apt_upgrade(upgrade_args=None):
    cmd = ['upgrade', '-y']
    if upgrade_args:
        cmd += upgrade_args
    lib.apt(cmd)


def get_dpkg_arch():
    return subprocess.run(['dpkg', '--print-architecture'],
                          capture_output=True,
                          check=True,
                          text=True).stdout.strip()


def install_initial_packages():
    apt_update()
    apt_install(['apt-transport-https', 'ca-certificates', 'curl', 'gnupg'])


def set_apt_variables():
    os.environ['APT_LISTCHANGES_FRONTEND'] = 'none'
    os.environ['DEBIAN_FRONTEND'] = 'noninteractive'
    os.environ['NEEDRESTART_SUSPEND'] = 'true'


def setup_doas(username, root_password):
    dpkg_arch = get_dpkg_arch()
    env_folder = lib.get_env_root()
    tmp_dir = None

    doas_ver = '6.8.2-1'
    if dpkg_arch == 'amd64':
        doas_ver += '+b1'
    doas_deb_file = f"opendoas_{doas_ver}_{dpkg_arch}.deb"

    if lib.get_glibc_version() > (2, 33, 0):
        tmp_dir = pathlib.Path(tempfile.mkdtemp())
        doas_deb = tmp_dir.joinpath(doas_deb_file)
        lib.curl([
            '-o', doas_deb, f"http://http.us.debian.org/debian/pool/main/o/opendoas/{doas_deb_file}"
        ])
    else:
        doas_deb = env_folder.joinpath('bin', 'packages', doas_deb_file)
    subprocess.run(['dpkg', '-i', doas_deb], check=True)

    doas_conf = pathlib.Path('/etc/doas.conf')
    doas_conf_text = ('# Allow me to be root for 5 minutes at a time\n'
                      f"permit persist {username} as root\n"
                      '# Do not require root to put in a password (makes no sense)\n'
                      'permit nopass root\n')
    doas_conf.write_text(doas_conf_text, encoding='utf-8')

    # Add a root password so that there is no warning about removing sudo
    lib.chpasswd('root', root_password)

    # Uninstall sudo but create a symlink in case a program expects only sudo
    lib.remove_if_installed('sudo')
    lib.setup_sudo_symlink()

    if tmp_dir:
        shutil.rmtree(tmp_dir)


def setup_docker(username):
    subprocess.run(['groupadd', '-f', 'docker'], check=True)
    lib.add_user_to_group('docker', username)

    # Pick up potential previous changes to daemon.json file
    for service in ['containerd', 'docker']:
        subprocess.run(['systemctl', 'restart', f"{service}.service"], check=True)


def setup_libvirt(username):
    if not lib.is_installed('virt-manager'):
        return
    lib.setup_libvirt(username)


def setup_locales():
    commands = [
        'locales locales/default_environment_locale select en_US.UTF-8',
        'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8',
    ]
    for command in commands:
        subprocess.run(['debconf-set-selections'], check=True, input=command, text=True)

    pathlib.Path('/etc/locale.gen').unlink(missing_ok=True)

    subprocess.run(['dpkg-reconfigure', '--frontend', 'noninteractive', 'locales'], check=True)


def update_and_install_packages(additional_packages=None):
    packages = [
        # b4
        'python3',
        'python3-dkim',
        'python3-requests',

        # doas
        'libpam0g',

        # docker
        'containerd.io',
        'docker-ce',
        'docker-ce-cli',
        'docker-compose-plugin',

        # Downloading/extracting utilities
        'bzip2',
        'ca-certificates',
        'curl',
        'unzip',
        'zip',
        'zstd',

        # email
        'mutt',

        # env
        'fish',
        'fzf',
        'jq',
        'neofetch',
        'python3-pip',
        'ripgrep',
        'stow',
        'tmux',
        'vim',

        # git
        'gh',
        'git',
        'git-email',
        'libauthen-sasl-perl',
        'libemail-valid-perl',
        'libio-socket-ssl-perl',
        'libnet-smtp-ssl-perl',

        # Miscellaneous
        'file',
        'locales',

        # Remote work
        'mosh',
        'ssh',

        # repo
        'python-is-python3'
    ]  # yapf: disable

    if additional_packages:
        packages += additional_packages

    # Install libvirt and needed packages on Equinix Metal servers.
    # Unconditionally install QEMU to get /dev/kvm setup properly.
    dpkg_arch = get_dpkg_arch()
    arch_packages = {
        'amd64': {
            'firmware': 'ovmf',
            'qemu': 'qemu-system-x86',
        },
        'arm64': {
            'firmware': 'qemu-efi-aarch64',
            'qemu': 'qemu-system-arm',
        },
    }
    if lib.is_equinix():
        packages += [
            'dnsmasq',
            'libvirt-daemon-system',
            'qemu-utils',
            'virt-manager',
            arch_packages[dpkg_arch]['firmware']
        ]  # yapf: disable
    packages += [arch_packages[dpkg_arch]['qemu']]

    add_apt_args = [
        '-o', 'Dpkg::Options::=--force-confdef', '-o', 'Dpkg::Options::=--force-confold'
    ]

    apt_update()
    apt_upgrade(add_apt_args)
    apt_install(add_apt_args + packages)
