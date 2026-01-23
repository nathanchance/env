#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

import contextlib
import shutil
import signal
import sys
import time
from argparse import ArgumentParser
from pathlib import Path

# we might be running '-h', just crash and burn later
with contextlib.suppress(ImportError):
    # pylint: disable-next=import-error,no-name-in-module
    import tuxmake.build

import korg_tc

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
# pylint: disable-next=wrong-import-position
import lib.utils


def interrupt_handler(_signum, _frame):
    sys.exit(130)


def parse_arguments():
    parser = ArgumentParser(description='Do a series of builds with GCC from kernel.org')

    supported_architectures = [
        'arm',
        'arm64',
        'i386',
        'mips',
        'powerpc',
        's390',
        'riscv',
        'x86_64',
    ]
    parser.add_argument('-a',
                        '--architectures',
                        choices=supported_architectures,
                        default=supported_architectures,
                        help='Architectures to build (default: all supported architectures)',
                        metavar='TARGETS',
                        nargs='+')

    suppported_toolchains = [f"gcc-{ver}" for ver in korg_tc.GCCManager.VERSIONS]
    parser.add_argument('-t',
                        '--toolchains',
                        choices=suppported_toolchains,
                        default=[suppported_toolchains[-1]],
                        help='Toolchains to build kernels with (default: latest GCC release)',
                        metavar='TOOLCHAINS',
                        nargs='+')

    supported_targets = ['def', 'all']
    parser.add_argument('-T',
                        '--targets',
                        choices=supported_targets,
                        default=supported_targets,
                        help='Targets to build (default: all supported targets)',
                        metavar='TARGETS',
                        nargs='+')

    default_kernel_source = Path().resolve()
    parser.add_argument('-C',
                        '--directory',
                        default=default_kernel_source,
                        help='Kernel source to build (default: current working directory)',
                        metavar='SOURCE')

    parser.add_argument(
        '-o',
        '--output-dir',
        help='Output folder for build artifacts (default: build folder in kernel source)')

    parser.add_argument('--use-ccache',
                        action='store_true',
                        help='Use ccache for builds (default: no caching)')

    return parser.parse_args()


def get_kconfigs_for_target(targets):
    kconfigs = {
        'all': ['allmodconfig', 'allnoconfig'],  # allyesconfig is not super useful and slow
        'def': ['defconfig'],
    }

    return [kconfig for target in targets for kconfig in kconfigs[target]]


def get_env_make_variables(target_arch, toolchain):
    environment = {}
    make_variables = {}

    if 'gcc' in toolchain:
        version = int(toolchain.split('-')[1])
        make_variables['CROSS_COMPILE'] = korg_tc.GCCManager().get_cc_as_path(version, target_arch)
        if target_arch == 'arm64':
            make_variables['CROSS_COMPILE_COMPAT'] = korg_tc.GCCManager().get_cc_as_path(
                version, 'arm')
        if version < 8:
            environment['KCFLAGS'] = ''

    return environment, make_variables


def get_targets(kconfig):
    targets = ['default']
    if kconfig == 'defconfig':
        targets.append('kernel')
    return targets


def build_one(tree, output_dir, target_arch, toolchain, wrapper, kconfig, results_file):
    bld_str = f"ARCH={target_arch} {kconfig} {toolchain}"

    lib.utils.print_header(bld_str)

    config_output_dir = f"{output_dir}/{target_arch}/{kconfig}"
    Path(config_output_dir).mkdir(exist_ok=True, parents=True)

    environment, make_variables = get_env_make_variables(target_arch, toolchain)

    # pylint: disable-next=c-extension-no-member
    result = tuxmake.build.build(tree=tree,
                                 output_dir=config_output_dir,
                                 target_arch=target_arch,
                                 wrapper=wrapper,
                                 kconfig=kconfig,
                                 environment=environment,
                                 make_variables=make_variables,
                                 targets=get_targets(kconfig))

    duration = 0
    passed = True
    for info in result.status.values():
        duration += info.duration
        passed &= info.passed

    res_str = 'PASS' if passed else 'FAIL'
    duration_str = lib.utils.get_duration(0, duration)
    with results_file.open(encoding='utf-8', mode='a') as file:
        file.write(f"{bld_str}: {res_str} in {duration_str}\n")


def process_results(results_file, start_time):
    print()

    failed = []
    passed = []
    for line in results_file.read_text(encoding='utf-8').splitlines(keepends=True):
        (passed if 'PASS' in line else failed).append(line)

    if passed:
        print('Successful builds:\n')
        print(''.join(passed))

    if failed:
        print('Failed builds:\n')
        print(''.join(failed))

    print(f"Total build time: {lib.utils.get_duration(start_time)}")


def build_all(linux_folder, out_folder, architectures, targets, toolchains, use_ccache,
              results_file):
    for toolchain in toolchains:
        for target_arch in architectures:
            if int(toolchain.split('-')[1]) < 7 and target_arch == 'riscv':
                continue
            for kconfig in get_kconfigs_for_target(targets):
                build_one(tree=linux_folder,
                          output_dir=out_folder,
                          target_arch=target_arch,
                          toolchain=toolchain,
                          wrapper='ccache' if use_ccache and shutil.which('ccache') else None,
                          kconfig=kconfig,
                          results_file=results_file)


if __name__ == '__main__':
    signal.signal(signal.SIGINT, interrupt_handler)

    args = parse_arguments()

    if not (output := args.output_dir):
        output = Path(args.directory, 'build')

    if (output := Path(output).resolve()).exists():
        shutil.rmtree(output)

    results = Path(output, 'results.log')
    start = time.time()

    build_all(linux_folder=Path(args.directory).resolve(),
              out_folder=output,
              architectures=args.architectures,
              targets=args.targets,
              toolchains=args.toolchains,
              use_ccache=args.use_ccache,
              results_file=results)

    process_results(results, start)
