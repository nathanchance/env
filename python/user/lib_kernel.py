#!/usr/bin/env python3

import datetime
from pathlib import Path
import os
import shutil
import subprocess
import time

import lib_user


# Basically '$binary --version | head -1'
def get_tool_version(binary_path):
    return subprocess.run([binary_path, '--version'], capture_output=True, check=True,
                          text=True).stdout.splitlines()[0]


def kmake(variables, targets, ccache=True, directory=None, jobs=None, silent=True, use_time=False):
    # Handle kernel directory right away
    if not (kernel_src := Path(directory) if directory else Path('.')).exists():
        raise Exception(f"Derived kernel source ('{kernel_src}') does not exist?")
    if not (makefile := Path(kernel_src, 'Makefile')).exists():
        raise Exception(f"Derived kernel source ('{kernel_src}') is not a kernel tree?")

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
                raise Exception(
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
                raise Exception(f"LLVM value ('{llvm}') neither begins with '-' nor ends with '/'!")
    # If we are not using clang, we have to be using gcc
    if not cc_str:
        cc_str = f"{cross_compile}gcc"

    if not (compiler := shutil.which(cc_str)):
        raise Exception(f"CC does not exist based on derived value ('{cc_str}')?")
    # Ensure compiler is a Path object for the .parent use below
    compiler_location = (compiler := Path(compiler)).parent

    # Handle ccache
    if ccache:
        if shutil.which('ccache'):
            variables['CC'] = f"ccache {compiler}"
        else:
            lib_user.print_yellow('WARNING: ccache requested by it could not be found, ignoring...')

    # V=1 or V=2 should imply '-v'
    if 'V' in variables:
        silent = False
    # Handle make flags
    flags = []
    if kernel_src.resolve() != Path.cwd().resolve():
        flags += ['-C', kernel_src]
    flags += [f"-{'s' if silent else ''}kj{jobs if jobs else os.cpu_count()}"]

    # Print information about current compiler
    lib_user.print_green(f"\nCompiler location:\033[0m {compiler_location}\n")
    lib_user.print_green(f"Compiler version:\033[0m {get_tool_version(compiler)}\n")

    # Print information about the binutils being used, if they are being used
    # Account for implicit LLVM_IAS change in f12b034afeb3 ("scripts/Makefile.clang: default to LLVM_IAS=1")
    ias_def_on = Path(kernel_src, 'scripts/Makefile.clang').exists()
    ias_def_val = 1 if cc_is_clang and ias_def_on else 0
    if int(variables.get('LLVM_IAS', ias_def_val)) == 0:
        if not (gnu_as := shutil.which(f"{cross_compile}as")):
            raise Exception(
                f"GNU as could not be found based on CROSS_COMPILE ('{cross_compile}')?")
        as_location = Path(gnu_as).parent
        if as_location != compiler_location:
            lib_user.print_green(f"Binutils location:\033[0m {as_location}\n")
        lib_user.print_green(f"Binutils version:\033[0m {get_tool_version(gnu_as)}\n")

    # Build and run make command
    make_cmd = [
        'stdbuf', '-eL', '-oL', 'make', *flags,
        *[f"{key}={variables[key]}" for key in sorted(variables)], *targets
    ]
    if use_time:
        if not (gnu_time := shutil.which('time')):
            raise Exception('Could not find time binary in PATH?')
        make_cmd = [gnu_time, '-v'] + make_cmd
    lib_user.print_cmd(make_cmd)
    if not use_time:
        start_time = time.time()
    subprocess.run(make_cmd, check=True)
    if not use_time:
        print(f"\nTime: {datetime.timedelta(seconds=int(time.time() - start_time))}")


def korg_gcc_canonicalize_target(value):
    if 'linux' in value:
        return value

    suffix = ''
    if value == 'arm':
        suffix = '-gnueabi'
    return f"{value}-linux{suffix}"


# GCC 6 through 12, GCC 5 is run in a container
def supported_korg_gcc_versions():
    return list(range(6, 13))


def supported_korg_gcc_arches():
    return [
        'aarch64',
        'arm',
        'i386',
        'm68k',
        'mips',
        'mips64',
        'powerpc',
        'powerpc64',
        'riscv32',
        'riscv64',
        's390',
        'x86_64',
    ]  # yapf: disable


def supported_korg_gcc_targets():
    return [korg_gcc_canonicalize_target(arch) for arch in supported_korg_gcc_arches()]
