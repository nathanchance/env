#!/usr/bin/env python3

import json
import os
import sys
from argparse import ArgumentParser
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.kernel
import lib.utils

# pylint: enable=wrong-import-position


def generate_patch_lines(args):
    if args.message_ids:
        for msg_id in args.message_ids:
            patch_txt = lib.kernel.b4_am_o(msg_id)
            _, subject = lib.kernel.get_msg_id_subject(patch_txt)

            print(
                f"patches.append('https://lore.kernel.org/all/{msg_id}/')  # {subject.split('] ', 1)[1]}",
            )

        return

    git_branch = lib.utils.get_git_output(args.directory, ['rev-parse', '--abbrev-ref', 'HEAD'])
    if not git_branch.startswith('b4/'):
        raise RuntimeError(f"Not on a b4 managed branch? Have: {git_branch}")

    series, commits = lib.kernel.b4_gen_series_commits(cwd=args.directory)

    # Get the message ID of the latest series
    base_msg_id = list(series.values())[-1]

    # For each commit in the list, generate a link to lore.kernel.org
    for idx, commit in enumerate(commits, 1):
        # Replace the patch number in the message ID, which is in the second to
        # last spot within the message ID when it is of the format in
        # <date>-<branch>-<version>-<patch>-<hash>@<address>
        # Convert to str to allow using join() below
        (new_msg_id := base_msg_id.rsplit('-', 2))[1] = str(idx)
        print(
            f"patches.append('https://lore.kernel.org/all/{'-'.join(new_msg_id)}/')  # {commit['title']}",
        )


def generate_pr_lines(args):
    for pr in args.prs:
        gh_pr_cmd = ['gh', '-R', 'llvm/llvm-project', 'pr', 'view', '--json', 'title,url', pr]
        info = json.loads(lib.utils.chronic(gh_pr_cmd).stdout)
        print(f"    set -a gh_prs {info['url']} # {info['title']}")


def generate_revert_lines(args):
    directory = args.directory if args.directory else Path(
        os.environ['CBL_SRC_D'], 'linux-next' if args.type == 'kernel' else 'llvm-project')
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
    patch_parser.add_argument(
        '-m',
        '--message-ids',
        help='Message IDs to generate lines for. By default, the current branch is looked at',
        nargs='*')

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
