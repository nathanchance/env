#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import copy
import json
import os
import shlex
import shutil
import socket
import subprocess
import sys
import time
from collections.abc import Sequence
from pathlib import Path

PathString = Path | str
ValidSingleCmd = str | bytes | os.PathLike
ValidCmd = ValidSingleCmd | Sequence[ValidSingleCmd]
CmdList = list[ValidSingleCmd]
PackageSequence = Sequence[PathString]
EnvVars = dict[str, str]


def call_git(directory: Path | None, cmd: ValidCmd, **kwargs) -> subprocess.CompletedProcess:
    kwargs.setdefault('cwd', directory)

    git_cmd: CmdList = ['git']
    if isinstance(cmd, ValidSingleCmd):
        git_cmd.append(cmd)
    else:
        git_cmd.extend(cmd)

    if kwargs.pop('show_cmd', False):
        cmd_to_print = git_cmd.copy()
        if kwargs['cwd']:
            cmd_to_print[1:1] = ['-C', kwargs['cwd']]
        print_cmd(cmd_to_print)

    return chronic(git_cmd, **kwargs)


def call_git_loud(directory: Path | None, cmd: ValidCmd, **kwargs) -> subprocess.CompletedProcess:
    return call_git(directory, cmd, **kwargs, capture_output=False)


def check_root() -> None:
    if os.geteuid() != 0:
        raise RuntimeError("root access is required!")


def chronic(args: ValidCmd, **kwargs) -> subprocess.CompletedProcess:
    kwargs.setdefault('capture_output', True)

    return run(args, **kwargs)


def curl(item_to_download: str, output: PathString | None = None) -> bytes:
    curl_cmd: CmdList = ['curl', '-LSs', item_to_download]
    if output:
        curl_cmd += ['-o', output]

    return chronic(curl_cmd, text=None).stdout


def detect_virt(args: ValidCmd | None = None) -> str:
    sdv_cmd: CmdList = ['systemd-detect-virt']
    if args:
        if isinstance(args, ValidSingleCmd):
            sdv_cmd.append(args)
        else:
            sdv_cmd.extend(args)
    return chronic(sdv_cmd, check=False).stdout.strip()


def fix_wrktrs_for_nspawn(git_repo: Path) -> None:
    if not git_repo.joinpath('.git').is_dir():
        raise RuntimeError(f"{git_repo} does not appear to be a git repository?")
    for gitdir in git_repo.glob('.git/worktrees/*/gitdir'):
        # Transform '/run/host/home/...' into '/home/...'
        if (gitdir_txt := gitdir.read_text(encoding='utf-8')).startswith('/run/host/'):
            gitdir.write_text(gitdir_txt[len('/run/host') :], encoding='utf-8')


def fzf(header: str, fzf_input: str, fzf_args: ValidCmd | None = None) -> list[str]:
    fzf_cmd: CmdList = ['fzf', '--header', header, '--multi']
    if fzf_args:
        if isinstance(fzf_args, ValidSingleCmd):
            fzf_cmd.append(fzf_args)
        else:
            fzf_cmd.extend(fzf_args)
    with subprocess.Popen(
        fzf_cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True
    ) as fzf_proc:
        return fzf_proc.communicate(fzf_input)[0].splitlines()


def get_duration(start_seconds: float, end_seconds: float | None = None) -> str:
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


def get_findmnt_info(path: str = '') -> dict[str, str]:
    fields = ('FSROOT', 'FSTYPE', 'OPTIONS', 'PARTUUID', 'SOURCE', 'UUID')
    findmnt_cmd = ['findmnt', '-J', '-o', ','.join(fields)]
    if path:
        findmnt_cmd.append(path)
    filesystems = json.loads(chronic(findmnt_cmd).stdout)['filesystems']
    if path:
        return filesystems[0]
    return filesystems


def get_hostname() -> str:
    return socket.gethostname()


def get_git_output(directory: Path | None, cmd: ValidCmd, **kwargs):
    return call_git(directory, cmd, **kwargs).stdout.strip()


def in_container() -> bool:
    if shutil.which('systemd-detect-virt'):
        val = detect_virt('-c')
        if val == 'lxc':
            # If MAC_FOLDER is set and we are in lxc, we are in OrbStack, which
            # is not really considered a container for the sake of this
            # function.
            return 'MAC_FOLDER' not in os.environ
        return val != 'none'

    return (
        'container' in os.environ
        or Path('/run/.containerenv').is_file()
        or Path('/.dockerenv').is_file()
    )


def in_nspawn() -> bool:
    # An nspawn container has to have systemd-detect-virt but this may not
    # always run where systemd-detect-virt exists.
    return shutil.which('systemd-detect-virt') is not None and detect_virt('-c') == 'systemd-nspawn'


def path_and_text(*args) -> tuple[Path, str]:
    if (path := Path(*args)).exists():
        return path, path.read_text(encoding='utf-8')
    return path, ''


def print_cmd(cmd: ValidCmd, show_cmd_location: bool = False, end: str = '\n') -> None:
    cmd_loc = ('(container) ' if in_container() else '(host) ') if show_cmd_location else ''
    if isinstance(cmd, ValidSingleCmd):
        cmd_str = cmd
    else:
        cmd_str = ' '.join(shlex.quote(str(elem)) for elem in cmd)
    print(f"{cmd_loc}$ {cmd_str}", end=end, flush=True)


def print_header(string: str) -> None:
    border = ''.join(["=" for _ in range(len(string) + 6)])
    print_cyan(f"\n{border}\n== {string} ==\n{border}\n")


def print_color(color: str, string: str) -> None:
    print(f"{color}{string}\033[0m" if sys.stdout.isatty() else string, flush=True)


def print_cyan(msg: str) -> None:
    print_color('\033[01;36m', msg)


def print_green(msg: str) -> None:
    print_color('\033[01;32m', msg)


def print_yellow(msg: str) -> None:
    print_color('\033[01;33m', msg)


def print_red(msg: str) -> None:
    print_color('\033[01;31m', msg)


def request_root(msg: str) -> None:
    print_green(f"Requesting root access for {msg}\n")
    run0('true')


def run(args: ValidCmd, **kwargs) -> subprocess.CompletedProcess:
    kwargs.setdefault('check', True)

    kwargs.setdefault('text', True)
    if (input_val := kwargs.get('input')) and not isinstance(input_val, str):
        kwargs['text'] = None

    if (show_cmd_location := kwargs.pop('show_cmd_location', False)) or kwargs.pop(
        'show_cmd', False
    ):
        print_cmd(args, show_cmd_location=show_cmd_location)

    if env := kwargs.pop('env', None):
        kwargs['env'] = os.environ | copy.deepcopy(env)

    try:
        # This function defaults check=True so if check=False here, it is explicit
        # pylint: disable-next=subprocess-run-check
        return subprocess.run(args, **kwargs)  # noqa: PLW1510
    except subprocess.CalledProcessError as err:
        if kwargs.get('capture_output'):
            print(err.stdout)
            print(err.stderr)
        raise err


def run0(full_cmd: ValidCmd, **kwargs) -> subprocess.CompletedProcess:
    if isinstance(full_cmd, ValidSingleCmd):
        cmd_copy: CmdList = [full_cmd]
    else:
        cmd_copy: CmdList = list(copy.deepcopy(full_cmd))

    if os.geteuid() != 0:
        cmd_copy.insert(0, 'doas' if shutil.which('doas') else 'sudo')

    # If we have to escalate via 'doas' or 'sudo', print the command so it can
    # be audited if necessary.
    return run(cmd_copy, show_cmd_location=cmd_copy[0] in ('doas', 'sudo'), **kwargs)


def run_check_rc_zero(args: ValidCmd, **kwargs) -> bool:
    return chronic(args, **kwargs, check=False).returncode == 0


def systemd_drop_in(service: str, drop_in_name: str, conf_txt: str) -> subprocess.CompletedProcess:
    return run0(
        ['systemctl', 'edit', '--stdin', '--drop-in', drop_in_name, service],
        input=conf_txt,
    )


def tg_msg(raw_msg: str) -> None:
    if not (botinfo := Path.home().joinpath('.botinfo')).exists():
        raise FileNotFoundError(f"{botinfo} could not be found!")
    chat_id, token = botinfo.read_text(encoding='utf-8').splitlines()

    msg = f"From {get_hostname()}:\n\n{raw_msg}"

    curl_cmd = (
        'curl',
        '-s',
        '-X',
        'POST',
        f"https://api.telegram.org/bot{token}/sendMessage",
        '-d',
        f"chat_id={chat_id}",
        '-d',
        'parse_mode=Markdown',
        '-d',
        f"text={msg}",
        '-o',
        '/dev/null',
    )
    chronic(curl_cmd)


def print_or_run_cmd(cmd, dryrun, end='\n\n') -> None:
    if dryrun:
        print_cmd(cmd, end=end)
    else:
        run(cmd)


def print_or_write_text(path: Path, text: str, dryrun: bool) -> None:
    if dryrun:
        print('Would write:\n')
        print(''.join(f"| {line}\n" for line in text.splitlines()))
        print(f"to {path}\n")
    else:
        path.write_text(text, encoding='utf-8')


def wget(item_to_download, output=None) -> bytes:
    wget_cmd: CmdList = [
        'wget',
        '-q',
        '-O',
        output if output else '-',
        item_to_download,
    ]
    return chronic(wget_cmd, text=None).stdout
