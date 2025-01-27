#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
from pathlib import Path
import re
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position


def parse_arguments():
    parser = ArgumentParser(
        description='Prepare an email build report from build logs generated with cbl_lkt')

    parser.add_argument('-p',
                        '--print-to-stdout',
                        action='store_true',
                        help='Print to stdout instead of writing to report.txt in log folder')
    parser.add_argument('folder', type=str, help='Path to build logs')

    return parser.parse_args()


def get_log(log_folder, key):
    return Path(log_folder, key + '.log')


def generate_warnings(log_folder, src_folder):
    # Get full list of logs from folder, excluding internal logs for filtering sake
    internal_files = {elem + '.log' for elem in ['failed', 'info', 'skipped', 'success']}
    internal_files.add('report.txt')
    logs = sorted([elem for elem in log_folder.iterdir() if elem.name not in internal_files])

    # Generate a full list of warnings across all builds, deduplicated per build
    searches = [
        'error:',
        'Error:',
        'ERROR:',
        'FAILED:',
        'FATAL:',
        'undefined',
        'Unsupported relocation type:',
        'warning:',
        'Warning:',
        'WARNING:',
    ]  # yapf: disable
    prob_re = re.compile('|'.join(searches))
    warnings = {}
    for log in logs:
        lines = log.read_text(encoding='utf-8').splitlines(keepends=True)
        # We specifically check "dodgy linker" because this is known to be
        # extremely noisy and will appear with most released versions of clang.
        # They will still appear in the log files but they do not need to be
        # logged in these reports.
        warnings[log.name] = sorted({
            line.replace(f"{src_folder}/", '')
            for line in lines if prob_re.search(line) and 'dodgy linker' not in line
        })
    full = {key: value for key, value in warnings.items() if value}

    # Filter warnings based on priority to fix
    merge_config_ignore = [
        'CPU_BIG_ENDIAN',
        'LTO_CLANG_THIN',
        'SQUASHFS_DECOMP_SINGLE',
        'SQUASHFS_DECOMP_MULTI',
        'SQUASHFS_DECOMP_MULTI_PERCPU',
    ]
    ignore = [
        # Too many to deal with for now
        'objtool:',
        '-Wframe-larger-than',
        # Warnings from merge_config that are harmless
        f"override: ({'|'.join(merge_config_ignore)}) changes choice state",
        # https://github.com/ClangBuiltLinux/linux/issues/1065
        r'union jset::\(anonymous at ./usr/include/linux/bcache.h:',
        # https://github.com/ClangBuiltLinux/linux/issues/1427
        "llvm-objdump: error: 'vmlinux': not a dynamic object",
        # https://github.com/ClangBuiltLinux/linux/issues/1315
        "unused during compilation: '-march=arm",
        # https://github.com/ClangBuiltLinux/linux/issues/1555
        r"scripts/(extract-cert|sign-file).c:[0-9]+:[0-9]+: warning: '(ENGINE|ERR)_.*' is deprecated \[-Wdeprecated-declarations\]",
        # New binutils warnings that are not clang specific:
        # https://sourceware.org/bugzilla/show_bug.cgi?id=29072
        'missing .note.GNU-stack section implies executable stack',
        r'requires executable stack \(because the .note.GNU-stack section is executable\)',
        'has a LOAD segment with RWX permissions',
        # https://github.com/llvm/llvm-project/issues/59037
        'error: write on a pipe with no reader',
        # https://github.com/ClangBuiltLinux/linux/issues/1415
        '(asmmacro.h|genex.S|[0-9]+):.*macro defined with named parameters',
        'macro local_irq_enable reg=',
        # new warning present with make 4.4:
        # https://lore.kernel.org/Y7i8+EjwdnhHtlrr@dev-arch.thelio-3990X/
        'llvm-nm: error: arch/arm/boot/compressed/../../../../vmlinux: No such file or directory',
        # Ignore all objdump warnings, most are from tool incompatibilities like DWARF5 handling
        'gnu-objdump: Warning:',
        # QEMU warnings, generally not useful
        'qemu-system-[a-z0-9]+: warning:',
        # QEMU warning for PowerPC on kernels prior to e4bb64c7a42e ("powerpc:
        # remove interrupt handler functions from the noinstr section") in
        # 5.12, backport is too hairy, just ignore.
        r"WARNING: CPU: [0-9]+ PID: [0-9]+ at arch/powerpc/kernel/optprobes.c:[0-9]+ kretprobe_trampoline\+",
        # Warning on boot when SRSO is not set, which is not really a problem
        # for our simple QEMU boots.
        'kernel not compiled with (CPU|MITIGATION)_SRSO',
        # Warning when SRSO is missing some option, harmless for our quick and
        # simple QEMU boots.
        'See https://kernel.org/doc/html/latest/admin-guide/hw-vuln/srso.html for mitigation options.',
        # Warning when CONFIG_NTFS3_64BIT_CLUSTER is enabled, which we do not
        # care about at all.
        'Activated 64 bits per cluster. Windows does not support this',
        # Python 3.12 warnings, not ClangBuiltLinux related
        'SyntaxWarning: invalid escape sequence',
        # Warning from LoongArch firmware, who cares?
        'Error: Image at [0-9A-F]+ start failed: Not Found',
    ]
    ignore_re = re.compile('|'.join(ignore))
    warnings = {}
    for log, problems in full.items():
        warnings[log] = sorted({item for item in problems if not ignore_re.search(item)})
    filtered = {key: value for key, value in warnings.items() if value}

    # Deduplicate warnings across all builds
    unique = sorted({item for problems in filtered.values() for item in problems})

    return full, filtered, unique


def generate_report(log_folder):
    # First, we need to figure out the source directory, so we can eliminate
    # its path from all the warnings, which makes the report a little easier to
    # read.
    if not (info_log := get_log(log_folder, 'info')).exists():
        raise RuntimeError('info.log does not exist?')
    info_text = info_log.read_text(encoding='utf-8')
    if not (match := re.search('^Linux source location: (.*)$', info_text, flags=re.M)):
        raise RuntimeError('Could not figure out source folder?')
    src_folder = Path(match.groups()[0])

    # Next, generate three items:
    # * full: A dictionary of lists, with the log name as the key and a sorted
    #         list of warnings in that file as the value.
    # * filtered: A dictionary of lists (same as full), filtered from an ignore
    #             list (see above).
    # * unique: A sorted list of unique warnings across the series of builds
    #           (so warnings seen in multiple builds are only seen once in the
    #           list).
    full, filtered, unique = generate_warnings(log_folder, src_folder)

    # Build report text based on log files and filtered warnings above.
    report_text = info_text

    if (failed_log := get_log(log_folder, 'failed')).exists():
        report_text += '\nList of failed tests:\n\n'
        report_text += failed_log.read_text(encoding='utf-8')

    if (skipped_log := get_log(log_folder, 'skipped')).exists():
        report_text += '\nList of skipped tests:\n\n'
        report_text += skipped_log.read_text(encoding='utf-8')

    if unique:
        report_text += '\nUnique warning report:\n\n'
        for warning in unique:
            report_text += warning

    if filtered:
        report_text += '\nFiltered warning report:\n\n'
        for log, warnings in filtered.items():
            for warning in warnings:
                report_text += f"{log}:{warning}"

    if (success_log := get_log(log_folder, 'success')).exists():
        report_text += '\nList of successful tests:\n\n'
        report_text += success_log.read_text(encoding='utf-8')

    if full:
        report_text += '\nFull warning report:\n\n'
        for log, warnings in full.items():
            for warning in warnings:
                report_text += f"{log}:{warning}"

    if src_folder.exists() and (mfc := lib.utils.get_git_output(src_folder, 'mfc')):
        report_text += f"\n{src_folder.name} commit logs:\n\n"
        branch = lib.utils.get_git_output(src_folder, 'bn')
        if remote := lib.utils.get_git_output(src_folder, ['rn', branch]):
            since = f"{remote}/{branch}"
        else:
            since = f"{mfc}^"
        report_text += lib.utils.call_git(src_folder, ['l', f"{since}^.."]).stdout

    return report_text


if __name__ == '__main__':
    args = parse_arguments()

    if not (folder := Path(args.folder)).exists():
        raise RuntimeError(f"Logs folder ('{folder}') could not be found!")

    report = generate_report(folder)
    if args.print_to_stdout:
        print(report, end='')  # report_text has '\n' at the end already
    else:
        Path(folder, 'report.txt').write_text(report, encoding='utf-8')
