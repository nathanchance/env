#!/usr/bin/env python3

from argparse import ArgumentParser
import json
import os
from pathlib import Path
import subprocess
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position


def generate_pr_lines(args):
    for pr in args.prs:
        gh_pr_cmd = ['gh', '-R', 'llvm/llvm-project', 'pr', 'view', '--json', 'title,url', pr]
        result = subprocess.run(gh_pr_cmd, capture_output=True, check=True, text=True)

        info = json.loads(result.stdout)
        print(f"    set -a gh_prs {info['url']} # {info['title']}")


def generate_revert_lines(args):
    if not args.no_update:
        lib.utils.call_git(args.directory, ['remote', 'update', '-p'])
    show_format = 'set -a reverts https://github.com/llvm/llvm-project/commit/%H # %s'
    for sha in args.shas:
        cmd = ['show', f"--format={show_format}", '--no-patch', sha]
        print(f"    {lib.utils.get_git_output(args.directory, cmd)}")


def parse_arguments():
    parser = ArgumentParser(description='Automatically generate variables for cbl_bld_tot_tcs')

    subparser = parser.add_subparsers(dest='subcommand', metavar='SUBCOMMAND', required=True)

    pr_parser = subparser.add_parser('pr', help='Generate gh_pr lines')
    pr_parser.add_argument('prs', help='Pull request numbers', nargs='*')

    revert_parser = subparser.add_parser('revert', help='Generate revert lines')
    revert_parser.add_argument('-C',
                               '--directory',
                               default=Path(os.environ['CBL_SRC'], 'llvm-project'),
                               help='Git repository to run commands in  (default: %(default)s)',
                               type=Path)
    revert_parser.add_argument('-n',
                               '--no-update',
                               action='store_true',
                               help='Do not update remotes in repo')
    revert_parser.add_argument('shas', help='SHAs of commits to revert', nargs='*')

    return parser.parse_args()


if __name__ == '__main__':
    arguments = parse_arguments()

    if arguments.subcommand == 'pr':
        generate_pr_lines(arguments)
    if arguments.subcommand == 'revert':
        generate_revert_lines(arguments)
