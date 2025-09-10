#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
from pathlib import Path
import shutil
import sys

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

    lib.utils.run(
        ['useradd', '-m', '-G', 'sudo' if lib.setup.group_exists('sudo') else 'wheel', user_name])
    lib.setup.chpasswd(user_name, user_password)

    root_ssh = Path.home().joinpath('.ssh')
    user_ssh = Path('/home', user_name, '.ssh')
    shutil.copytree(root_ssh, user_ssh)
    lib.setup.chown(user_name, user_ssh)


def parse_arguments():
    parser = ArgumentParser(description='Perform initial setup on certain servers')

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

    lib.utils.check_root()

    drive = args.drive
    folder = Path(args.folder)
    password = args.password
    user = args.user

    if drive:
        check_install()
        lib.setup.partition_drive(drive, folder, user)

    if password:
        create_user(user, password)
