#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
from os import environ as env
from pathlib import Path
import shutil
import subprocess
import sys
import time

import deb

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
import lib.utils
# pylint: enable=wrong-import-position


def check_install():
    if shutil.which('sgdisk') or shutil.which('parted'):
        return

    if shutil.which('pacman'):
        lib.setup.pacman(['-Syyu', '--noconfirm', 'parted'])
    elif shutil.which('apt'):
        deb.apt_update()
        deb.apt_install(['parted'])
    else:
        raise RuntimeError('parted is needed but it cannot be installed on the current OS!')


def create_user(user_name, user_password):
    if lib.setup.user_exists(user_name):
        raise RuntimeError(f"user ('{user_name}') already exists?")

    subprocess.run(
        ['useradd', '-m', '-G', 'sudo' if lib.setup.group_exists('sudo') else 'wheel', user_name],
        check=True)
    lib.setup.chpasswd(user_name, user_password)

    root_ssh = Path.home().joinpath('.ssh')
    user_ssh = Path('/home', user_name, '.ssh')
    shutil.copytree(root_ssh, user_ssh)
    lib.setup.chown(user_name, user_ssh)


def partition_drive(drive_path, mountpoint, username):
    if not drive_path.startswith(('/dev/nvme', '/dev/sd')):
        raise RuntimeError(f"Cannot safely handle drive path '{drive_path}'?")

    volume = Path(drive_path + 'p1' if '/dev/nvme' in drive_path else '1')

    if mountpoint.is_mount():
        raise RuntimeError(f"mountpoint ('{mountpoint}') is already mounted?")

    if volume.is_block_device():
        raise RuntimeError(f"volume ('{volume}') already exists?")

    if shutil.which('sgdisk'):
        subprocess.run(['sgdisk', '-N', '1', '-t', '1:8300', drive_path], check=True)
    else:
        subprocess.run([
            'parted',
            '-s',
            drive_path,
            'mklabel',
            'gpt',
            'mkpart',
            'primary',
            'ext4',
            '0%',
            '100%',
        ],
                       check=True)
        # Let everything sync up
        time.sleep(10)

    subprocess.run(['mkfs', '-t', 'ext4', volume],
                   check=True,
                   env={
                       **env,
                       'E2FSPROGS_LIBMAGIC_SUPPRESS': '1',
                   })

    vol_uuid = subprocess.run(['blkid', '-o', 'value', '-s', 'UUID', volume],
                              capture_output=True,
                              check=True,
                              text=True).stdout.strip()

    fstab = lib.setup.Fstab()
    fstab[mountpoint] = lib.setup.FstabItem(f"UUID={vol_uuid}", mountpoint, 'ext4', 'defaults', '0',
                                            '2')
    fstab.write()

    mountpoint.mkdir(exist_ok=True, parents=True)
    subprocess.run(['mount', '-a'], check=True)
    if mountpoint != Path('/home'):
        lib.setup.chown(username, mountpoint)


def parse_arguments():
    parser = ArgumentParser(description='Perform initial setup on Equinix Metal servers')

    parser.add_argument('-d',
                        '--drive',
                        help='Drive to create folder on (default: no partitioning)')
    parser.add_argument('-f',
                        '--folder',
                        default='/home',
                        help='Mountpoint of partiton (default: /home)')
    parser.add_argument('-p',
                        '--password',
                        help='Password of user account (implies account creation)')
    parser.add_argument('-u', '--user', default=lib.setup.get_user(), help='Name of user account')

    return parser.parse_args()


if __name__ == '__main__':
    args = parse_arguments()

    lib.setup.check_root()

    drive = args.drive
    folder = Path(args.folder)
    password = args.password
    user = args.user

    if drive:
        check_install()
        partition_drive(drive, folder, user)

    if password:
        create_user(user, password)
