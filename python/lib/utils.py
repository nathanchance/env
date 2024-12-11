#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import copy
import os
from pathlib import Path
import shlex
import subprocess
import shutil
import sys
import time


def call_git(directory, cmd, **kwargs):
    kwargs.setdefault('cwd', directory)

    git_cmd = ['git']
    (git_cmd.append if isinstance(cmd, (str, os.PathLike)) else git_cmd.extend)(cmd)

    if kwargs.pop('show_cmd', False):
        cmd_to_print = git_cmd.copy()
        if kwargs['cwd']:
            cmd_to_print[1:1] = ['-C', kwargs['cwd']]
        print_cmd(cmd_to_print)

    return chronic(git_cmd, **kwargs)


def call_git_loud(directory, cmd, **kwargs):
    return call_git(directory, cmd, **kwargs, capture_output=False)


def chronic(*args, **kwargs):
    kwargs.setdefault('capture_output', True)

    return run(*args, **kwargs)


def curl(cmd, **kwargs):
    kwargs.setdefault('text', None)

    curl_cmd = ['curl', '-LSs']
    (curl_cmd.append if isinstance(cmd, str) else curl_cmd.extend)(cmd)

    return chronic(curl_cmd, **kwargs).stdout


def detect_virt(*args):
    return chronic(['systemd-detect-virt', *args], check=False).stdout.strip()


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


def get_git_output(directory, cmd, **kwargs):
    return call_git(directory, cmd, **kwargs).stdout.strip()


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


def print_cmd(cmd, show_cmd_location=False, end='\n'):
    if show_cmd_location:
        cmd_loc = '(container) ' if in_container() else '(host) '
    else:
        cmd_loc = ''
    if isinstance(cmd, (str, os.PathLike)):
        cmd_str = cmd
    else:
        cmd_str = ' '.join(shlex.quote(str(elem)) for elem in cmd)
    print(f"{cmd_loc}$ {cmd_str}", end=end, flush=True)


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


def run(*args, **kwargs):
    kwargs.setdefault('check', True)

    kwargs.setdefault('text', True)
    if (input_val := kwargs.get('input')) and not isinstance(input_val, str):
        kwargs['text'] = None

    if (show_cmd_location := kwargs.pop('show_cmd_location', False)) or kwargs.pop(
            'show_cmd', False):
        print_cmd(*args, show_cmd_location=show_cmd_location)

    if env := kwargs.pop('env', None):
        kwargs['env'] = os.environ | copy.deepcopy(env)

    try:
        # This function defaults check=True so if check=False here, it is explicit
        # pylint: disable-next=subprocess-run-check
        return subprocess.run(*args, **kwargs)  # noqa: PLW1510
    except subprocess.CalledProcessError as err:
        if kwargs.get('capture_output'):
            print(err.stdout)
            print(err.stderr)
        raise err


def run_as_root(full_cmd):
    cmd_copy = [full_cmd] if isinstance(full_cmd, (str, os.PathLike)) else full_cmd.copy()

    if os.geteuid() != 0:
        cmd_copy.insert(0, 'sudo')

    # If we have to escalate via 'sudo', print the command so it can be audited
    # if necessary.
    run(cmd_copy, show_cmd_location=cmd_copy[0] == 'sudo')


def run_check_rc_zero(*args, **kwargs):
    return chronic(*args, **kwargs, check=False).returncode == 0


def print_or_run_cmd(cmd, dryrun, end='\n\n'):
    if dryrun:
        print_cmd(cmd, end=end)
    else:
        run(cmd)


def print_or_write_text(path, text, dryrun):
    if dryrun:
        print('Would write:\n')
        print(''.join(f"| {line}\n" for line in text.splitlines()))
        print(f"to {path}\n")
    else:
        path.write_text(text, encoding='utf-8')
