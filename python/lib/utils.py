#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import os
from pathlib import Path
import shlex
import subprocess
import shutil
import sys
import time


def call_git(directory, cmd):
    return subprocess.run(['git', *cmd], capture_output=True, check=True, cwd=directory, text=True)


def detect_virt(*args):
    return subprocess.run(['systemd-detect-virt', *args],
                          capture_output=True,
                          check=False,
                          text=True).stdout.strip()


def get_duration(start_seconds, end_seconds=None):
    if not end_seconds:
        end_seconds = time.time()
    seconds = int(end_seconds - start_seconds)
    days, seconds = divmod(seconds, 60 * 60 * 24)
    hours, seconds = divmod(seconds, 60 * 60)
    minutes, seconds = divmod(seconds, 60)

    parts = []
    if days:
        parts.append(f"{days}d")
    if hours:
        parts.append(f"{hours}h")
    if minutes:
        parts.append(f"{minutes}m")
    parts.append(f"{seconds}s")

    return ' '.join(parts)


def get_git_output(directory, cmd):
    return call_git(directory, cmd).stdout.strip()


def in_container():
    if shutil.which('systemd-detect-virt'):
        val = detect_virt('-c')
        if val == 'lxc':
            # If MAC_FOLDER is set and we are in lxc, we are in OrbStack, which
            # is not really considered a container for the sake of this
            # function.
            return 'MAC_FOLDER' not in os.environ
        return val != 'none'

    return 'container' in os.environ or Path('/run/.containerenv').is_file() or Path(
        '/.dockerenv').is_file()


def path_and_text(*args):
    if (path := Path(*args)).exists():
        return path, path.read_text(encoding='utf-8')
    return path, None


def print_cmd(command, show_cmd_location=False):
    if show_cmd_location:
        cmd_loc = '(container) ' if in_container() else '(host) '
    else:
        cmd_loc = ''
    print(f"{cmd_loc}$ {' '.join([shlex.quote(str(elem)) for elem in command])}", flush=True)


def print_header(string):
    border = ''.join(["=" for _ in range(len(string) + 6)])
    print_cyan(f"\n{border}\n== {string} ==\n{border}\n")


def print_color(color, string):
    print(f"{color}{string}\033[0m" if sys.stdout.isatty() else string, flush=True)


def print_cyan(msg):
    print_color('\033[01;36m', msg)


def print_green(msg):
    print_color('\033[01;32m', msg)


def print_yellow(msg):
    print_color('\033[01;33m', msg)


def print_red(msg):
    print_color('\033[01;31m', msg)


def run_as_root(full_cmd):
    cmd_copy = full_cmd.copy()
    # If we have to escalate via 'sudo', print the command so it can be audited
    # if necessary.
    if os.geteuid() != 0:
        cmd_copy.insert(0, 'sudo')
        print_cmd(cmd_copy, show_cmd_location=True)
    subprocess.run(cmd_copy, check=True)


def print_or_write_text(path, text, dryrun):
    if dryrun:
        print('Would write:\n')
        print(''.join(f"| {line}\n" for line in text.splitlines()))
        print(f"to {path}\n")
    else:
        path.write_text(text, encoding='utf-8')
