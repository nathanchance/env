#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

from argparse import ArgumentParser
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.setup
import lib.utils

YES_ARG = '-y'


def brew(brew_args):
    lib.utils.run(['/opt/homebrew/bin/brew', *brew_args], show_cmd=True)


parser = ArgumentParser(description='Update distribution')
parser.add_argument(YES_ARG, '--yes', action='store_true', help='Run noninteratively')
args = parser.parse_args()

if sys.platform == 'darwin':
    cmd_func = brew
    cmds = [
        ['update'],
        ['upgrade'],
        ['upgrade', '--cask', 'wezterm@nightly', '--no-quarantine', '--greedy-latest'],
    ]
    YES_ARG = None
else:
    os_rel = lib.setup.get_os_rel()

    if os_rel['ID'] == 'arch':
        if not lib.utils.run_check_rc_zero(['checkupdates']):
            sys.exit(0)

        cmd_func = lib.setup.pacman
        cmds = [['-Syyu']]
        YES_ARG = '--noconfirm'

    elif os_rel['ID'] in ('almalinux', 'fedora', 'rocky'):
        cmd_func = lib.setup.dnf
        cmds = [['update']]

    elif os_rel['ID'] == 'alpine':
        cmd_func = lib.setup.apk
        cmds = [
            ['update'],
            ['upgrade'],
        ]
        YES_ARG = None

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
    if args.yes and YES_ARG and YES_ARG not in cmd:
        cmd.append(YES_ARG)
    cmd_func(cmd)
