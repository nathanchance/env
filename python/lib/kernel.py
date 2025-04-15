#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import email
import os
from pathlib import Path
import shutil
from subprocess import CalledProcessError
import sys
from tempfile import TemporaryDirectory
import time

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position

NEXT_TREES = ('fedora', 'linux-next-llvm', 'rpi')
PACMAN_TREES = ('linux-mainline-llvm', 'linux-next-llvm')


def b4(cmd, **kwargs):
    b4_cmd = ['b4']
    (b4_cmd.append if isinstance(cmd, str) else b4_cmd.extend)(cmd)

    if 'XDG_FOLDER' in os.environ:
        if 'env' not in kwargs:
            kwargs['env'] = {}
        kwargs['env'] |= {
            'XDG_CACHE_HOME': Path(os.environ['XDG_FOLDER'], 'cache'),
            'XDG_CONFIG_HOME': Path(os.environ['XDG_FOLDER'], 'config'),
            'XDG_DATA_HOME': Path(os.environ['XDG_FOLDER'], 'share'),
        }

    return lib.utils.run(b4_cmd, **kwargs)


def b4_am_o(msg_id, **kwargs):
    with TemporaryDirectory() as tmpdir:
        b4(['am', '-o', tmpdir, '--no-parent', '-P', '_', msg_id], **kwargs, capture_output=True)
        if len(patches := list(Path(tmpdir).iterdir())) != 1:
            raise RuntimeError(f"More than one patch in {tmpdir}? Have: {patches}")
        return patches[0].read_text(encoding='utf-8')


def b4_info(**kwargs):
    output = b4(['prep', '--show-info'], **kwargs, capture_output=True).stdout
    return dict(map(str.strip, item.split(':', 1)) for item in output.splitlines())


def b4_gen_series_commits(info=None, **kwargs):
    if not info:
        info = b4_info(**kwargs)

    # Order series keys as 'series-v1', 'series-v2', so that the last entry is the latest version
    series_keys = sorted(key for key in info if key.startswith('series-v'))
    # Commit keys are normally in "git log" order; reverse them so they are in patch application order
    (commit_keys := [key for key in info if key.startswith('commit-')]).reverse()

    commits = [{'key': key, 'title': info[key]} for key in commit_keys]
    series = {key.replace('series-', ''): info[key].rsplit(' ', 1)[1] for key in series_keys}

    return series, commits


def get_msg_id_subject(mail_str):
    msg = email.message_from_string(mail_str)

    if not (subject := msg.get('Subject')):
        raise RuntimeError('Cannot find subject in headers?')
    if not (msg_id := msg.get('Message-ID')):
        raise RuntimeError('Cannot find message-ID in headers?')

    # Transform <message-id> into message-id
    msg_id = msg_id.strip('<').rstrip('>')

    # Unwrap subject if necessary
    if '\n' in subject:
        subject = ''.join(subject.splitlines())

    return msg_id, subject


def prepare_source(base_name, base_ref='origin/master'):
    if base_name == 'linux-debug':
        return  # managed outside of the script
    if base_name not in (*NEXT_TREES, 'linux-mainline-llvm'):
        raise RuntimeError(f"Don't know how to handle provided base_name ('{base_name}')?")

    source_folder = Path(os.environ['CBL_SRC_P'], base_name)

    lib.utils.call_git(source_folder, ['remote', 'update', '--prune', 'origin'])
    lib.utils.call_git_loud(source_folder, ['reset', '--hard', base_ref])

    reverts = []
    patches = []
    commits = []

    # Patching section
    # yapf: disable
    if base_name == 'fedora':
        # https://lore.kernel.org/20250317174840.GA1451320@ax162/
        commits.append('792b2809cfc22e27b4e6616a8bcfab017773de82')  # Partially revert "kunit/fortify: Replace "volatile" with OPTIMIZER_HIDE_VAR()"
    if base_name == 'linux-next-llvm':
        patches.append('https://lore.kernel.org/all/20250414-x86-boot-startup-lto-error-v1-1-7c8bed7c131c@kernel.org/')  # x86/boot/startup: Disable LTO
    # yapf: enable

    try:
        for revert in reverts:
            if isinstance(revert, tuple):
                commit_range = revert[0]
                commit_msg = revert[1]

                if '..' not in commit_range:
                    raise RuntimeError(f"No git range indicator in {commit_range}")

                # generate diff from range
                range_diff = lib.utils.call_git(source_folder, ['diff', commit_range]).stdout

                # apply diff in reverse
                lib.utils.call_git_loud(source_folder, ['apply', '--3way', '--reverse'],
                                        input=range_diff)

                # commit the result
                lib.utils.call_git_loud(source_folder,
                                        ['commit', '--no-gpg-sign', '-m', commit_msg])
            else:
                lib.utils.call_git_loud(
                    source_folder,
                    ['revert', '--mainline', '1', '--no-edit', '--no-gpg-sign', revert])

        for patch in patches:
            am_cmd = ['am', '-3', '--no-gpg-sign']
            am_kwargs = {}

            if isinstance(patch, Path):
                am_cmd.append(patch)
            elif patch.startswith('https://lore.kernel.org/'):
                am_kwargs['input'] = b4_am_o(patch)
            elif patch.startswith(('https://', 'http://')):
                am_kwargs['input'] = lib.utils.curl(patch).decode('utf-8')
            elif patch.lstrip().startswith('From ') and 'diff --git' in patch:
                am_kwargs['input'] = patch
            else:
                raise RuntimeError(f"Can't handle {patch}?")

            lib.utils.call_git_loud(source_folder, am_cmd, **am_kwargs)

        for commit in commits:
            patch_input = lib.utils.call_git(Path(os.environ['CBL_SRC_P'], 'linux-next'),
                                             ['fp', '-1', '--stdout', commit]).stdout
            lib.utils.call_git_loud(source_folder, ['am', '-3'], input=patch_input)
    except CalledProcessError as err:
        lib.utils.call_git(source_folder, 'ama', check=False)
        print(f"\n[FAILED] {' '.join(err.cmd)}")
        sys.exit(err.returncode)


# Basically '$binary --version | head -1'
def get_tool_version(binary_path):
    return lib.utils.chronic([binary_path, '--version']).stdout.splitlines()[0]


def kmake(variables,
          targets,
          ccache=True,
          directory=None,
          env=None,
          jobs=None,
          silent=True,
          stdin=None,
          use_time=False):
    # Handle kernel directory right away
    if not (kernel_src := Path(directory) if directory else Path()).exists():
        raise RuntimeError(f"Derived kernel source ('{kernel_src}') does not exist?")
    if not (makefile := Path(kernel_src, 'Makefile')).exists():
        raise RuntimeError(f"Derived kernel source ('{kernel_src}') is not a kernel tree?")

    # Get compiler related variables
    cc_str = variables.get('CC', '')
    cross_compile = variables.get('CROSS_COMPILE', '')
    llvm = variables.get('LLVM', '')

    # We want to check certain conditions but we do not want override the
    # user's CC choice if there was one, hence the 'if not cc_str' sprinked
    # throughout this block.
    if (cc_is_clang := llvm or 'clang' in cc_str):
        # If CC was not explicitly specified, we need to figure out what it is
        # to print the location and version information
        if llvm == '1':
            if not cc_str:
                cc_str = 'clang'
        elif llvm:
            # We always want to check that the tree in question supports an
            # LLVM value other than 1
            if 'LLVM_PREFIX' not in makefile.read_text(encoding='utf-8'):
                raise RuntimeError(
                    f"Derived kernel source ('{kernel_src}') does not support LLVM other than 1!")
            # We want to check that LLVM is a correct value but we do not want
            # to override the user's CC choice if there was one
            if llvm[0] == '-':
                if not cc_str:
                    cc_str = f"clang{llvm}"
            elif llvm[-1] == '/':
                if not cc_str:
                    cc_str = f"{llvm}clang"
            else:
                raise RuntimeError(
                    f"LLVM value ('{llvm}') neither begins with '-' nor ends with '/'!")
    # If we are not using clang, we have to be using gcc
    if not cc_str:
        cc_str = f"{cross_compile}gcc"

    if not (compiler := shutil.which(cc_str)):
        raise RuntimeError(f"CC does not exist based on derived value ('{cc_str}')?")
    # Ensure compiler is a Path object for the .parent use below
    compiler_location = (compiler := Path(compiler)).parent

    # Handle ccache
    if ccache:
        if shutil.which('ccache'):
            variables['CC'] = f"ccache {compiler}"
        else:
            lib.utils.print_yellow(
                'WARNING: ccache requested by it could not be found, ignoring...')

    # V=1 or V=2 should imply '-v'
    if 'V' in variables:
        silent = False
    # Handle make flags
    flags = []
    if kernel_src.resolve() != Path().resolve():
        flags += ['-C', kernel_src]
    flags += [f"-{'s' if silent else ''}kj{jobs if jobs else os.cpu_count()}"]

    # Print information about current compiler
    lib.utils.print_green(f"\nCompiler location:\033[0m {compiler_location}\n")
    lib.utils.print_green(f"Compiler version:\033[0m {get_tool_version(compiler)}\n")

    # Print information about the binutils being used, if they are being used
    # Account for implicit LLVM_IAS change in f12b034afeb3 ("scripts/Makefile.clang: default to LLVM_IAS=1")
    ias_def_on = Path(kernel_src, 'scripts/Makefile.clang').exists()
    ias_def_val = 1 if cc_is_clang and ias_def_on else 0
    if int(variables.get('LLVM_IAS', ias_def_val)) == 0:
        if not (gnu_as := shutil.which(f"{cross_compile}as")):
            raise RuntimeError(
                f"GNU as could not be found based on CROSS_COMPILE ('{cross_compile}')?")
        as_location = Path(gnu_as).parent
        if as_location != compiler_location:
            lib.utils.print_green(f"Binutils location:\033[0m {as_location}\n")
        lib.utils.print_green(f"Binutils version:\033[0m {get_tool_version(gnu_as)}\n")

    # Build and run make command
    make_cmd = [
        'stdbuf', '-eL', '-oL', 'make',
        *flags,
        *[f"{key}={variables[key]}" for key in sorted(variables)],
        *targets,
    ]  # yapf: disable
    if use_time:
        if not (gnu_time := shutil.which('time')):
            raise RuntimeError('Could not find time binary in PATH?')
        make_cmd = [gnu_time, '-v', *make_cmd]
    else:
        start_time = time.time()
    try:
        lib.utils.run(make_cmd, env=env, stdin=stdin, show_cmd=True)
    finally:
        if not use_time:
            # pylint: disable-next=possibly-used-before-assignment
            print(f"\nTime: {lib.utils.get_duration(start_time)}")
