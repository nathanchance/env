#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from pathlib import Path
import shlex
import subprocess
import time


def call_git(directory, cmd):
    return subprocess.run(['git', *cmd], capture_output=True, check=True, cwd=directory, text=True)


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


def path_and_text(*args):
    if (path := Path(*args)).exists():
        return path, path.read_text(encoding='utf-8')
    return path, None


def print_cmd(command):
    print(f"$ {' '.join([shlex.quote(str(elem)) for elem in command])}", flush=True)


def print_header(string):
    border = ''.join(["=" for _ in range(len(string) + 6)])
    print_cyan(f"\n{border}\n== {string} ==\n{border}\n")


def print_color(color, string):
    print(f"{color}{string}\033[0m", flush=True)


def print_cyan(msg):
    print_color('\033[01;36m', msg)


def print_green(msg):
    print_color('\033[01;32m', msg)


def print_yellow(msg):
    print_color('\033[01;33m', msg)
