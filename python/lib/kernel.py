#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import email
import os
import shutil
import sys
import time
from pathlib import Path
from subprocess import CalledProcessError, CompletedProcess
from tempfile import TemporaryDirectory

sys.path.append(str(Path(__file__).resolve().parents[1]))
import lib.utils

NEXT_TREES: tuple[str, ...] = ('fedora', 'linux-next-llvm')
PACMAN_TREES: tuple[str, ...] = ('linux-mainline-llvm', 'linux-next-llvm')


def b4(cmd: lib.utils.ValidCmd, **kwargs) -> CompletedProcess:
    b4_cmd: lib.utils.CmdList = ['b4']
    if isinstance(cmd, lib.utils.ValidSingleCmd):
        b4_cmd.append(cmd)
    else:
        b4_cmd.extend(cmd)

    return lib.utils.run(b4_cmd, **kwargs)


def b4_am_o(msg_id: str, **kwargs) -> str:
    with TemporaryDirectory() as tmpdir:
        b4(
            ['am', '-o', tmpdir, '--no-parent', '-P', '_', msg_id],
            **kwargs,
            capture_output=True,
        )
        if len(patches := list(Path(tmpdir).iterdir())) != 1:
            msg = f"More than one patch in {tmpdir}? Have: {patches}"
            raise RuntimeError(msg)
        return patches[0].read_text(encoding='utf-8')


def b4_info(**kwargs) -> dict[str, str]:
    output = b4(['prep', '--show-info'], **kwargs, capture_output=True).stdout

    return dict([item.split(': ', 1) for item in output.splitlines()])


def b4_gen_series_commits(
    info: dict[str, str] | None = None, **kwargs
) -> tuple[dict[str, str], list[dict[str, str]]]:
    if not info:
        info = b4_info(**kwargs)

    # Order series keys as 'series-v1', 'series-v2', so that the last entry is the latest version
    series_keys = sorted(key for key in info if key.startswith('series-v'))
    # Commit keys are normally in "git log" order; reverse them so they are in patch application order
    (commit_keys := [key for key in info if key.startswith('commit-')]).reverse()

    commits = [{'key': key, 'title': info[key]} for key in commit_keys]
    series = {key.replace('series-', ''): info[key].rsplit(' ', 1)[1] for key in series_keys}

    return series, commits


def get_msg_id_subject(mail_str: str) -> tuple[str, str]:
    mail_msg = email.message_from_string(mail_str)

    if not (subject := mail_msg.get('Subject')):
        msg = 'Cannot find subject in headers?'
        raise RuntimeError(msg)
    if not (msg_id := mail_msg.get('Message-ID')):
        msg = 'Cannot find message-ID in headers?'
        raise RuntimeError(msg)

    # Transform <message-id> into message-id
    msg_id = msg_id.strip('<').rstrip('>')

    # Unwrap subject if necessary
    if '\n' in subject:
        subject = ''.join(subject.splitlines())

    return msg_id, subject


def prepare_source(base_name: str, base_ref: str = 'origin/master') -> None:
    if base_name == 'linux-debug':
        return  # managed outside of the script
    if base_name not in {*NEXT_TREES, 'linux-mainline-llvm'}:
        msg = f"Don't know how to handle provided base_name ('{base_name}')?"
        raise RuntimeError(msg)

    source_folder = Path(os.environ['CBL_SRC_P'], base_name)

    lib.utils.call_git(source_folder, ['remote', 'update', '--prune', 'origin'])
    lib.utils.call_git_loud(source_folder, ['reset', '--hard', base_ref])

    reverts: list[str] = []
    patches: list[str] = []
    commits: list[str] = []

    # Patching section
    if base_name in NEXT_TREES:
        patches.append(
            'https://lore.kernel.org/all/20260428-ntfs-fix-sometimes-uninit-rl-v1-1-31e0c8025430@kernel.org/'
        )  # ntfs: Use return instead of goto in ntfs_mapping_pairs_decompress()

    if base_name in PACMAN_TREES:
        patches.append('''From e2b85cda2be7dcaefd908d283a6be1a40bbd843e Mon Sep 17 00:00:00 2001
From: Nathan Chancellor <nathan@kernel.org>
Date: Mon, 13 Apr 2026 15:22:57 -0700
Subject: [PATCH] HACK: drm/amd/display: Hide two instances of
 -Wframe-larger-than in display_mode_vba_31{,4}.o

Signed-off-by: Nathan Chancellor <nathan@kernel.org>
---
 drivers/gpu/drm/amd/display/dc/dml/Makefile | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)

diff --git a/drivers/gpu/drm/amd/display/dc/dml/Makefile b/drivers/gpu/drm/amd/display/dc/dml/Makefile
index 268b5fbdb48b..c1189707efcf 100644
--- a/drivers/gpu/drm/amd/display/dc/dml/Makefile
+++ b/drivers/gpu/drm/amd/display/dc/dml/Makefile
@@ -56,9 +56,9 @@ CFLAGS_$(AMDDALPATH)/dc/dml/dcn21/display_mode_vba_21.o := $(dml_ccflags) $(fram
 CFLAGS_$(AMDDALPATH)/dc/dml/dcn21/display_rq_dlg_calc_21.o := $(dml_ccflags)
 CFLAGS_$(AMDDALPATH)/dc/dml/dcn30/display_mode_vba_30.o := $(dml_ccflags) $(frame_warn_flag)
 CFLAGS_$(AMDDALPATH)/dc/dml/dcn30/display_rq_dlg_calc_30.o := $(dml_ccflags)
-CFLAGS_$(AMDDALPATH)/dc/dml/dcn31/display_mode_vba_31.o := $(dml_ccflags) $(frame_warn_flag)
+CFLAGS_$(AMDDALPATH)/dc/dml/dcn31/display_mode_vba_31.o := $(dml_ccflags) -Wframe-larger-than=2160
 CFLAGS_$(AMDDALPATH)/dc/dml/dcn31/display_rq_dlg_calc_31.o := $(dml_ccflags)
-CFLAGS_$(AMDDALPATH)/dc/dml/dcn314/display_mode_vba_314.o := $(dml_ccflags) $(frame_warn_flag)
+CFLAGS_$(AMDDALPATH)/dc/dml/dcn314/display_mode_vba_314.o := $(dml_ccflags) -Wframe-larger-than=2160
 CFLAGS_$(AMDDALPATH)/dc/dml/dcn314/display_rq_dlg_calc_314.o := $(dml_ccflags)
 CFLAGS_$(AMDDALPATH)/dc/dml/dcn314/dcn314_fpu.o := $(dml_ccflags)
 CFLAGS_$(AMDDALPATH)/dc/dml/dcn30/dcn30_fpu.o := $(dml_ccflags)
-- 
2.53.0

''')  # noqa: W291

    try:
        for revert in reverts:
            if isinstance(revert, tuple):
                commit_range = revert[0]
                commit_msg = revert[1]

                if '..' not in commit_range:
                    msg = f"No git range indicator in {commit_range}"
                    raise RuntimeError(msg)

                # generate diff from range
                range_diff = lib.utils.call_git(source_folder, ['diff', commit_range]).stdout

                # apply diff in reverse
                lib.utils.call_git_loud(
                    source_folder, ['apply', '--3way', '--reverse'], input=range_diff
                )

                # commit the result
                lib.utils.call_git_loud(
                    source_folder, ['commit', '--no-gpg-sign', '-m', commit_msg]
                )
            else:
                lib.utils.call_git_loud(
                    source_folder,
                    ['revert', '--mainline', '1', '--no-edit', '--no-gpg-sign', revert],
                )

        for patch in patches:
            am_cmd = ['am', '-3', '--no-gpg-sign']
            am_kwargs = {}

            if isinstance(patch, Path):
                am_cmd.append(patch)
            elif patch.startswith('https://lore.kernel.org/') and not patch.endswith('/raw'):
                am_kwargs['input'] = b4_am_o(patch)
            elif patch.startswith(('https://', 'http://')):
                # curl is banned due to bot attacks
                fetch_func = lib.utils.wget if 'lore.kernel.org' in patch else lib.utils.curl
                am_kwargs['input'] = fetch_func(patch).decode('utf-8', 'ignore')
            elif patch.lstrip().startswith('From ') and 'diff --git' in patch:
                am_kwargs['input'] = patch
            else:
                msg = f"Can't handle {patch}?"
                raise RuntimeError(msg)

            lib.utils.call_git_loud(source_folder, am_cmd, **am_kwargs)

        for commit in commits:
            patch_input = lib.utils.call_git(
                Path(os.environ['CBL_SRC_P'], 'linux-next'),
                ['fp', '-1', '--stdout', commit],
            ).stdout
            lib.utils.call_git_loud(source_folder, ['am', '-3'], input=patch_input)
    except CalledProcessError as err:
        lib.utils.call_git(source_folder, 'ama', check=False)
        print(f"\n[FAILED] {' '.join(err.cmd)}")
        sys.exit(err.returncode)


# Basically '$binary --version | head -1'
def get_tool_version(binary_path: Path | str) -> str:
    return lib.utils.chronic([binary_path, '--version']).stdout.splitlines()[0]


def kmake(
    variables: lib.utils.MakeVars,
    targets: list[str],
    ccache: bool = True,
    directory: Path | None = None,
    env: lib.utils.EnvVars | lib.utils.MakeVars | None = None,
    jobs: int | None = None,
    silent: bool = True,
    stdin: str | None = None,
    use_time: bool = False,
) -> None:
    # Handle kernel directory right away
    if not (kernel_src := Path(directory) if directory else Path()).exists():
        msg = f"Derived kernel source ('{kernel_src}') does not exist?"
        raise RuntimeError(msg)
    if not (makefile := Path(kernel_src, 'Makefile')).exists():
        msg = f"Derived kernel source ('{kernel_src}') is not a kernel tree?"
        raise RuntimeError(msg)

    # Get compiler related variables
    cc_str = variables.get('CC', '')
    cross_compile = variables.get('CROSS_COMPILE', '')
    llvm = variables.get('LLVM', '')

    # We want to check certain conditions but we do not want override the
    # user's CC choice if there was one, hence the 'if not cc_str' sprinked
    # throughout this block.
    if cc_is_clang := llvm or 'clang' in cc_str:
        # If CC was not explicitly specified, we need to figure out what it is
        # to print the location and version information
        if llvm == '1':
            if not cc_str:
                cc_str = 'clang'
        elif llvm:
            # We always want to check that the tree in question supports an
            # LLVM value other than 1
            if 'LLVM_PREFIX' not in makefile.read_text(encoding='utf-8'):
                msg = f"Derived kernel source ('{kernel_src}') does not support LLVM other than 1!"
                raise RuntimeError(msg)
            # We want to check that LLVM is a correct value but we do not want
            # to override the user's CC choice if there was one
            if llvm[0] == '-':
                if not cc_str:
                    cc_str = f"clang{llvm}"
            elif llvm[-1] == '/':
                if not cc_str:
                    cc_str = f"{llvm}clang"
            else:
                msg = f"LLVM value ('{llvm}') neither begins with '-' nor ends with '/'!"
                raise RuntimeError(msg)
    # If we are not using clang, we have to be using gcc
    if not cc_str:
        cc_str = f"{cross_compile}gcc"

    if not (compiler := shutil.which(cc_str)):
        msg = f"CC does not exist based on derived value ('{cc_str}')?"
        raise RuntimeError(msg)
    # Ensure compiler is a Path object for the .parent use below
    compiler_location = (compiler := Path(compiler)).parent

    # Handle ccache
    if ccache:
        if shutil.which('ccache'):
            variables['CC'] = f"ccache {compiler}"
        else:
            lib.utils.print_yellow(
                'WARNING: ccache requested by it could not be found, ignoring...'
            )

    # V=1 or V=2 should imply '-v'
    if 'V' in variables:
        silent = False
    # Handle make flags
    flags = []
    if kernel_src.resolve() != Path.cwd():
        flags += ['-C', kernel_src]
    flags += [f"-{'s' if silent else ''}kj{jobs or os.cpu_count()}"]

    # Print information about current compiler
    lib.utils.print_green(f"\nCompiler location:\033[0m {compiler_location}\n")
    lib.utils.print_green(f"Compiler version:\033[0m {get_tool_version(compiler)}\n")

    # Print information about the binutils being used, if they are being used
    # Account for implicit LLVM_IAS change in f12b034afeb3 ("scripts/Makefile.clang: default to LLVM_IAS=1")
    ias_def_on = Path(kernel_src, 'scripts/Makefile.clang').exists()
    ias_def_val = 1 if cc_is_clang and ias_def_on else 0
    if int(variables.get('LLVM_IAS', ias_def_val)) == 0:
        if not (gnu_as := shutil.which(f"{cross_compile}as")):
            msg = f"GNU as could not be found based on CROSS_COMPILE ('{cross_compile}')?"
            raise RuntimeError(msg)
        as_location = Path(gnu_as).parent
        if as_location != compiler_location:
            lib.utils.print_green(f"Binutils location:\033[0m {as_location}\n")
        lib.utils.print_green(f"Binutils version:\033[0m {get_tool_version(gnu_as)}\n")

    # Build and run make command
    make_cmd: lib.utils.CmdList = [
        'stdbuf', '-eL', '-oL', 'make',
        *flags,
        *[f"{key}={variables[key]}" for key in sorted(variables)],
        *targets,
    ]  # fmt: off
    if use_time:
        if not (gnu_time := shutil.which('time')):
            msg = 'Could not find time binary in PATH?'
            raise RuntimeError(msg)
        make_cmd = [gnu_time, '-v', *make_cmd]
    else:
        start_time = time.time()
    try:
        lib.utils.run(make_cmd, env=env, stdin=stdin, show_cmd=True)
    finally:
        if not use_time:
            print(f"\nTime: {lib.utils.get_duration(start_time)}")
