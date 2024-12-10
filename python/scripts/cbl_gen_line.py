#!/usr/bin/env python3

from argparse import ArgumentParser
import json
import os
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position


def generate_patch_lines(args):
    git_branch = lib.utils.get_git_output(args.directory, ['rev-parse', '--abbrev-ref', 'HEAD'])
    if not git_branch.startswith('b4/'):
        raise RuntimeError(f"Not on a b4 managed branch? Have: {git_branch}")

    b4_info_raw = lib.utils.chronic(['b4', 'prep', '--show-info'], cwd=args.directory).stdout
    b4_info = dict(item.split(': ', 1) for item in b4_info_raw.splitlines())

    commit_keys = []
    latest_series = 1
    for key in b4_info:
        if 'commit-' in key:
            commit_keys.insert(0, key)  # to ensure the commits remain in order
        if 'series-v' in key and (series_ver := int(key.replace('series-v', ''))) > latest_series:
            latest_series = series_ver

    base_msg_id = b4_info[f"series-v{latest_series}"].split(' ', 1)[1]
    for idx, commit in enumerate(commit_keys, 1):
        (new_msg_id := base_msg_id.rsplit('-', 2))[1] = str(idx)
        print(
            f"patches.append('https://lore.kernel.org/all/{'-'.join(new_msg_id)}/')  # {b4_info[commit]}",
        )


def generate_pr_lines(args):
    for pr in args.prs:
        gh_pr_cmd = ['gh', '-R', 'llvm/llvm-project', 'pr', 'view', '--json', 'title,url', pr]
        info = json.loads(lib.utils.chronic(gh_pr_cmd).stdout)
        print(f"    set -a gh_prs {info['url']} # {info['title']}")


def generate_revert_lines(args):
    directory = args.directory if args.directory else Path(
        os.environ['CBL_SRC_D'], 'linux' if args.type == 'kernel' else 'llvm-project')
    if not args.no_update:
        lib.utils.call_git(directory, ['remote', 'update', '-p', 'origin'])
    if args.type == 'kernel':
        show_format = "reverts.append('%H')  # %s"
    else:
        show_format = 'set -a reverts https://github.com/llvm/llvm-project/commit/%H # %s'
    cmd = ['show', f"--format={show_format}", '--no-patch', *args.shas]
    print(f"    {lib.utils.get_git_output(directory, cmd)}")


def parse_arguments():
    parser = ArgumentParser(
        description='Automatically generate variables for cbl_bld_tot_tcs and python/lib/kernel.py')

    subparser = parser.add_subparsers(dest='subcommand', metavar='SUBCOMMAND', required=True)

    patch_parser = subparser.add_parser('patch', help='Generate python/lib/kernel.py patch lines')
    patch_parser.add_argument('-C',
                              '--directory',
                              default=Path.cwd(),
                              help='Git repository to run commands in (default: %(default)s)',
                              type=Path)

    pr_parser = subparser.add_parser('pr', help='Generate cbl_bld_tot_tcs gh_pr lines')
    pr_parser.add_argument('prs', help='Pull request numbers', nargs='*')

    revert_parser = subparser.add_parser('revert', help='Generate cbl_bld_tot_tcs revert lines')
    revert_parser.add_argument('-C',
                               '--directory',
                               help='Git repository to run commands in',
                               type=Path)
    revert_parser.add_argument('-k',
                               '--kernel',
                               action='store_const',
                               const='kernel',
                               dest='type',
                               help='Generate items in kernel format')
    revert_parser.add_argument('-l',
                               '--llvm',
                               action='store_const',
                               const='llvm',
                               dest='type',
                               help='Generate items in LLVM format')
    revert_parser.add_argument('-n',
                               '--no-update',
                               action='store_true',
                               help='Do not update remotes in repo')
    revert_parser.add_argument('shas', help='SHAs of commits to revert', nargs='*')

    return parser.parse_args()


if __name__ == '__main__':
    arguments = parse_arguments()

    if arguments.subcommand == 'patch':
        generate_patch_lines(arguments)
    if arguments.subcommand == 'pr':
        generate_pr_lines(arguments)
    if arguments.subcommand == 'revert':
        generate_revert_lines(arguments)
