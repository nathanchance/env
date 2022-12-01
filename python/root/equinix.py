#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

import argparse
import pathlib
import shutil
import subprocess
import time

import deb
import lib


def check_install_parted():
    if shutil.which('parted'):
        return

    if shutil.which('apt'):
        deb.apt_update()
        deb.apt_install(['parted'])

    raise Exception('parted is needed but it cannot be installed on the current OS!')


def create_user(user_name, user_password):
    if lib.user_exists(user_name):
        raise Exception(f"user ('{user_name}') already exists?")

    subprocess.run(
        ['useradd', '-m', '-G', 'sudo' if lib.group_exists('sudo') else 'wheel', user_name],
        check=True)
    lib.chpasswd(user_name, user_password)

    root_ssh = pathlib.Path.home().joinpath('.ssh')
    user_ssh = pathlib.Path('/home').joinpath(user_name, '.ssh')
    shutil.copytree(root_ssh, user_ssh)
    lib.chown(user_name, user_ssh)


def partition_drive(drive_path, mountpoint, username):
    if '/dev/nvme' in drive_path:
        part = 'p1'
    elif '/dev/sd' in drive_path:
        part = '1'

    volume = pathlib.Path(drive_path + part)

    if mountpoint.is_mount():
        raise Exception(f"mountpoint ('{mountpoint}') is already mounted?")

    if volume.is_block_device():
        raise Exception(f"volume ('{volume}') already exists?")

    subprocess.run(
        ['parted', '-s', drive_path, 'mklabel', 'gpt', 'mkpart', 'primary', 'ext4', '0%', '100%'],
        check=True)
    # Let everything sync up
    time.sleep(10)

    subprocess.run(['mkfs', '-t', 'ext4', volume], check=True)

    vol_uuid = subprocess.run(['blkid', '-o', 'value', '-s', 'UUID', volume],
                              capture_output=True,
                              check=True,
                              text=True).stdout.strip()

    fstab = pathlib.Path('/etc/fstab')
    fstab_txt = fstab.read_text(encoding='utf-8')
    fstab_line = f"UUID={vol_uuid}\t{mountpoint}\text4\tnoatime\t0\t2\n"
    fstab.write_text(fstab_txt + fstab_line, encoding='utf-8')
    subprocess.run(['systemctl', 'daemon-reload'], check=True)

    mountpoint.mkdir(exist_ok=True, parents=True)
    subprocess.run(['mount', '-a'], check=True)
    if mountpoint != pathlib.Path('/home'):
        lib.chown(username, mountpoint)


def parse_arguments():
    parser = argparse.ArgumentParser(description='Perform initial setup on Equinix Metal servers')

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
    parser.add_argument('-u', '--user', default='nathan', help='Name of user account')

    return parser.parse_args()


if __name__ == '__main__':
    args = parse_arguments()

    lib.check_root()

    drive = args.drive
    folder = pathlib.Path(args.folder)
    password = args.password
    user = args.user

    if drive:
        check_install_parted()
        partition_drive(drive, folder, user)

    if password:
        create_user(user, password)
