#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
import re
import subprocess


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
    return log_folder.joinpath(key + '.log')


def git_get(repo, cmd):
    return subprocess.run(['git', *cmd], capture_output=True, check=True, cwd=repo,
                          text=True).stdout


def filter_warnings(log_folder, src_folder):
    # Get full list of logs from folder, excluding internal logs for filtering sake
    internal_files = {elem + '.log' for elem in ['failed', 'info', 'skipped', 'success']}
    internal_files.add('report.txt')
    logs = [elem for elem in log_folder.iterdir() if elem.name not in internal_files]

    # Generate a full list of warnings across all builds
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
    warnings = {}
    for log in logs:
        with open(log, encoding='utf-8') as file:
            warnings[log.name] = set()
            for line in file:
                if re.search(f"{'|'.join(searches)}", line):
                    warnings[log.name].add(re.sub(f"{src_folder}/", '', line))
    full = {key: value for key, value in warnings.items() if value}

    # Deduplicate warnings within files
    dedup = sorted({(file, item) for file, value in full.items() for item in value})

    # Filter warnings based on priority to fix
    ignore = [
        # Too many to deal with for now
        'objtool:',
        '-Wframe-larger-than',
        # Warnings from merge_config that are harmless
        'override: (CPU_BIG_ENDIAN|LTO_CLANG_THIN) changes choice state',
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
    ]
    ignore_re = re.compile('|'.join(ignore))
    filtered = sorted({item for item in dedup if not ignore_re.search(item[1])})

    # Deduplicate warnings across all builds
    unique = sorted({item[1] for item in filtered})

    return dedup, filtered, unique


def generate_report(log_folder):
    # First, we need to figure out the source directory, so we can eliminate
    # its path from all the warnings, which makes the report a little easier to
    # read.
    if not (info_log := get_log(log_folder, 'info')).exists():
        raise Exception('info.log does not exist?')
    info_text = info_log.read_text(encoding='utf-8')
    if not (match := re.search('^Linux source location: (.*)$', info_text, flags=re.M)):
        raise Exception('Could not figure out source folder?')
    src_folder = Path(match.groups()[0])

    # Next, generate three items:
    # * dedup: A set of tuples of file name and warning.
    # * filtered: A set of tuples of file name and warning, filted from
    #             an ignore list (see above).
    # * unique: A set of warnings (so warnings seen in multiple builds
    #           are only seen once in the list).
    dedup, filtered, unique = filter_warnings(log_folder, src_folder)

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
        for warning in filtered:
            report_text += f"{warning[0]}:{warning[1]}"

    report_text += '\nList of successful tests:\n\n'
    report_text += get_log(log_folder, 'success').read_text(encoding='utf-8')

    if dedup:
        report_text += '\nFull warning report:\n\n'
        for warning in dedup:
            report_text += f"{warning[0]}:{warning[1]}"

    if src_folder.exists():
        mfc = git_get(src_folder, ['mfc']).strip()
        if mfc:
            report_text += f"\n{src_folder.name} commit logs:\n\n"
            report_text += git_get(src_folder, ['l', f"{mfc}^^.."])

    return report_text


if __name__ == '__main__':
    args = parse_arguments()

    if not (folder := Path(args.folder)).exists():
        raise Exception(f"Logs folder ('{folder}') could not be found!")

    report = generate_report(folder)
    if args.print_to_stdout:
        print(report, end='')  # report_text has '\n' at the end already
    else:
        folder.joinpath('report.txt').write_text(report, encoding='utf-8')
