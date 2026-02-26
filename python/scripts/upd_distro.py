#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

import sys
from argparse import ArgumentParser
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
import lib.utils

yes_arg = '-y'


def brew(brew_args):
    lib.utils.run(['/opt/homebrew/bin/brew', *brew_args], show_cmd=True)


parser = ArgumentParser(description='Update distribution')
parser.add_argument(yes_arg, '--yes', action='store_true', help='Run noninteratively')
args = parser.parse_args()

if sys.platform == 'darwin':
    cmd_func = brew
    cmds = [
        ['update'],
        ['upgrade'],
        ['upgrade', '--cask', 'wezterm@nightly', '--no-quarantine', '--greedy-latest'],
    ]
    yes_arg = None
else:
    os_rel = lib.setup.get_os_rel()

    if os_rel['ID'] == 'arch':
        checkupdates = lib.utils.chronic(['checkupdates'], check=False)
        if (cu_ret := checkupdates.returncode) == 2:
            sys.exit(0)
        elif cu_ret == 1:
            print("checkupdates failed with:")
            if checkupdates.stderr:
                print(checkupdates.stderr, end='')
            if checkupdates.stdout:
                print(checkupdates.stdout, end='')
            sys.exit(1)
        elif cu_ret == 0:
            pass
        else:
            raise RuntimeError(f"Unhandled checkupdates return code: {cu_ret}")

        cmd_func = lib.setup.pacman
        cmds = [['-Syyu']]
        yes_arg = '--noconfirm'

    elif os_rel['ID'] in ('almalinux', 'fedora', 'fedora-asahi-remix', 'rocky'):
        cmd_func = lib.setup.dnf
        cmds = [['update']]

    elif os_rel['ID'] == 'alpine':
        cmd_func = lib.setup.apk
        cmds = [
            ['update'],
            ['upgrade'],
        ]
        yes_arg = None

    elif os_rel['ID'] in ('debian', 'raspbian', 'ubuntu'):
        cmd_func = lib.setup.apt
        cmds = [
            ['update'],
            ['full-upgrade'],
            ['autoremove', '-y'],
        ]

    elif 'opensuse' in os_rel['ID']:
        cmd_func = lib.setup.zypper
        cmds = [['dup']]

    else:
        raise RuntimeError(f"Don't know how to handle '{os_rel['ID']}'?")

for cmd in cmds:
    if args.yes and yes_arg and yes_arg not in cmd:
        cmd.append(yes_arg)
    cmd_func(cmd)
