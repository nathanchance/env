#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import os
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
import lib.utils

# pylint: enable=wrong-import-position


def apt_install(install_args):
    lib.setup.apt(['install', '-y', '--no-install-recommends', *install_args])


def apt_update():
    lib.setup.apt(['update', '-qq'])


def apt_upgrade(upgrade_args=None):
    cmd = ['upgrade', '-y']
    if upgrade_args:
        cmd += upgrade_args
    lib.setup.apt(cmd)


def get_dpkg_arch():
    return lib.utils.chronic(['dpkg', '--print-architecture']).stdout.strip()


def install_initial_packages():
    apt_update()
    apt_install(['apt-transport-https', 'ca-certificates', 'curl', 'gnupg'])


def set_apt_variables():
    os.environ['APT_LISTCHANGES_FRONTEND'] = 'none'
    os.environ['DEBIAN_FRONTEND'] = 'noninteractive'
    os.environ['NEEDRESTART_SUSPEND'] = 'true'


def setup_doas(username, root_password):
    dpkg_arch = get_dpkg_arch()
    env_folder = lib.setup.get_env_root()
    tmp_dir = None

    doas_ver = '6.8.2-1'
    if dpkg_arch == 'amd64':
        doas_ver += '+b1'
    doas_deb_file = f"opendoas_{doas_ver}_{dpkg_arch}.deb"

    if lib.setup.get_glibc_version() > (2, 33, 0):
        tmp_dir = Path(tempfile.mkdtemp())
        doas_deb = Path(tmp_dir, doas_deb_file)
        lib.utils.curl(f"http://http.us.debian.org/debian/pool/main/o/opendoas/{doas_deb_file}",
                       output=doas_deb)
    else:
        doas_deb = Path(env_folder, 'bin/packages', doas_deb_file)
    lib.utils.run(['dpkg', '-i', doas_deb])

    doas_conf = Path('/etc/doas.conf')
    doas_conf_text = (
        '# Allow me to be root for 5 minutes at a time\n'
        f"permit persist {username} as root\n"
        '\n'
        '# Do not require root to put in a password (makes no sense)\n'
        'permit nopass root\n'
        '\n'
        '# Allow me to update packages without a password (arguments are matched exactly)\n'
        f"permit nopass {username} as root cmd apt args update\n"
        f"permit nopass {username} as root cmd apt args update -y\n"
        f"permit nopass {username} as root cmd apt args full-upgrade\n"
        f"permit nopass {username} as root cmd apt args full-upgrade -y\n"
        f"permit nopass {username} as root cmd apt args autoremove\n"
        f"permit nopass {username} as root cmd apt args autoremove -y\n")
    if lib.setup.is_virtual_machine():
        doas_conf_text += ('\n'
                           '# Allow me to passwordlessly reboot and poweroff virtual machine\n'
                           f"permit nopass {username} as root cmd poweroff\n"
                           f"permit nopass {username} as root cmd systemctl args poweroff\n"
                           f"permit nopass {username} as root cmd reboot\n"
                           f"permit nopass {username} as root cmd systemctl args reboot\n")
    doas_conf.write_text(doas_conf_text, encoding='utf-8')

    # Add a root password so that there is no warning about removing sudo
    lib.setup.chpasswd('root', root_password)

    # Uninstall sudo but create a symlink in case a program expects only sudo
    lib.setup.remove_if_installed('sudo')
    lib.setup.setup_sudo_symlink()

    if tmp_dir:
        shutil.rmtree(tmp_dir)


def setup_docker(username):
    lib.utils.run(['groupadd', '-f', 'docker'])
    lib.setup.add_user_to_group('docker', username)

    # Pick up potential previous changes to daemon.json file
    for service in ['containerd', 'docker']:
        lib.utils.run(['systemctl', 'restart', f"{service}.service"])


def setup_libvirt(username):
    if not lib.setup.is_installed('virt-manager'):
        return
    lib.setup.setup_libvirt(username)


def setup_locales():
    commands = [
        'locales locales/default_environment_locale select en_US.UTF-8',
        'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8',
    ]
    for command in commands:
        lib.utils.run('debconf-set-selections', input=command)

    Path('/etc/locale.gen').unlink(missing_ok=True)

    lib.utils.run(['dpkg-reconfigure', '--frontend', 'noninteractive', 'locales'])


def update_and_install_packages(additional_packages=None):
    packages = [
        # doas
        'libpam0g',

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
        'python3',
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
        'acl',
        'file',
        'locales',

        # mkosi / systemd-nspawn
        'patch',
        'polkitd',
        'systemd-container',

        # Remote work
        'mosh',
        'ssh',

        # repo
        'python-is-python3',
    ]  # yapf: disable

    # Container manager
    if Path('/etc/apt/sources.list.d/docker.sources').exists():
        packages += [
            'containerd.io',
            'docker-ce',
            'docker-ce-cli',
            'docker-compose-plugin',
        ]
    else:
        packages += [
            'aardvark-dns',
            'buildah',
            'catatonit',
            'dbus-user-session',
            'podman',
            'slirp4netns',
            'uidmap',
        ]

    if additional_packages:
        packages += additional_packages

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
    if dpkg_arch in arch_packages:
        packages += [arch_packages[dpkg_arch]['qemu']]

    add_apt_args = [
        '-o', 'Dpkg::Options::=--force-confdef',
        '-o', 'Dpkg::Options::=--force-confold',
    ]  # yapf: disable

    apt_update()
    apt_upgrade(add_apt_args)
    apt_install(add_apt_args + packages)
