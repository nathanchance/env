#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import os
from pathlib import Path
import shutil
from subprocess import CalledProcessError
import sys
import time

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position

NEXT_TREES = ('fedora', 'linux-next-llvm', 'rpi')
PACMAN_TREES = ('linux-mainline-llvm', 'linux-next-llvm')


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
    if base_name in ('fedora', 'linux-next-llvm'):
        # https://lore.kernel.org/20241114163931.GA1928968@thelio-3990X/
        commits.append('bd0601e8f99ded716ae1341c39cf8cc30fc28466')  # fixup! netfs: Change the read result collector to only use one work item

        patches.append('https://lore.kernel.org/all/20241210-bcachefs-fix-declaration-after-label-err-v1-1-22c705fc47e8@kernel.org/')  # bcachefs: Add empty statement between label and declaration in check_inode_hash_info_matches_root()

    if base_name == 'linux-next-llvm':
        # https://lore.kernel.org/20241212014418.GA532802@ax162/
        reverts.append('5a82223e0743fb36bcb99657772513739d1a9936')  # x86/kexec: Mark relocate_kernel page as ROX instead of RWX
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
                lib.utils.call_git_loud(source_folder, ['commit', '-m', commit_msg])
            else:
                lib.utils.call_git_loud(source_folder,
                                        ['revert', '--mainline', '1', '--no-edit', revert])

        for patch in patches:
            if isinstance(patch, Path):
                lib.utils.call_git_loud(source_folder, ['am', '-3', patch])
            elif patch.startswith('https://lore.kernel.org/'):
                lib.utils.run(['b4', 'shazam', '-l', '-P', '_', '-s', patch], cwd=source_folder)
            elif patch.startswith(('https://', 'http://')):
                patch_input = lib.utils.curl([patch]).decode('utf-8')
                lib.utils.call_git_loud(source_folder, ['am', '-3'], input=patch_input)
            else:
                raise RuntimeError(f"Can't handle {patch}?")

        for commit in commits:
            patch_input = lib.utils.call_git(Path(os.environ['CBL_SRC_P'], 'linux-next'),
                                             ['fp', '-1', '--stdout', commit]).stdout
            lib.utils.call_git_loud(source_folder, ['am', '-3'], input=patch_input)
    except CalledProcessError as err:
        lib.utils.call_git(source_folder, 'ama', check=False)
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
