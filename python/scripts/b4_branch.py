#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
import re
from subprocess import Popen, PIPE
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.kernel
import lib.utils
# pylint: enable=wrong-import-position


def clean_branch(directory, branch, tags, arguments):
    # Figure out what remote items we have to clean up if we are not in remote only mode
    if arguments.remote_only:
        remote_items = [f":{branch}"]
        remote_items += [f":{tag}" for tag in tags]
    else:
        remote_refs = get_remote_b4_branches()
        remote_items = []
        if branch in remote_refs:
            remote_items.append(f":{branch}")
        remote_items += [f":{tag}" for tag in tags if tag in remote_refs]

    # Clean remote branch first in case it fails, there is still local copy
    if remote_items:
        git_push_cmd = ['push', 'korg', *remote_items]
        if arguments.dry_run:
            lib.utils.print_cmd(['git', '-C', directory, *git_push_cmd])
        else:
            lib.utils.call_git_loud(directory, git_push_cmd)

    # Clean up local branches and tags
    # Not using b4() because of the pipe from yes for non-interactivity
    if not arguments.remote_only:
        b4_cmd = ['prep', '--cleanup', branch]
        if arguments.dry_run:
            lib.utils.print_cmd(b4_cmd)
        else:
            with Popen(['yes', ''], stdout=PIPE) as yes_proc:
                lib.kernel.b4(b4_cmd, cwd=directory, stdin=yes_proc.stdout)


def filter_branches(desired_branches, possible_branches):
    filtered_branches = {}

    for branch in desired_branches:
        if branch not in possible_branches:
            raise RuntimeError(
                f"Requested branch ('{branch}') is not in the list of b4-managed branches?")
        filtered_branches[branch] = possible_branches[branch]

    return filtered_branches


def gen_b4_branches(b4_branches, b4_tags):
    return {
        branch: tuple(tag for tag in b4_tags if branch.strip('b4/') in tag)
        for branch in b4_branches
    }


def get_b4_branches(directory):
    b4_branches = lib.utils.get_git_output(
        directory, ['for-each-ref', '--format=%(refname:short)', 'refs/heads/b4/']).splitlines()
    b4_tags = lib.utils.get_git_output(
        directory, ['for-each-ref', '--format=%(refname:short)', 'refs/tags/sent/']).splitlines()
    return gen_b4_branches(b4_branches, b4_tags)


def get_remote_b4_branches():
    korg_repo = 'https://git.kernel.org/pub/scm/linux/kernel/git/nathan/linux.git/'
    git_ls_remote_cmd = ['ls-remote', '--heads', '--tags', korg_repo]
    git_ls_remote_output = lib.utils.get_git_output(None, git_ls_remote_cmd)

    b4_branches = re.findall('refs/heads/(b4/.*)$', git_ls_remote_output, flags=re.M)
    b4_tags = set(re.findall('refs/tags/(sent/[^^{}\n\t]+)', git_ls_remote_output))

    return gen_b4_branches(b4_branches, b4_tags)


def parse_arguments():
    parser = ArgumentParser(description='Manage b4-managed branches')
    subparser = parser.add_subparsers(dest='subcommand', metavar='SUBCOMMAND', required=True)

    common_parser = ArgumentParser(add_help=False)
    common_parser.add_argument('-a',
                               '--all',
                               action='store_true',
                               help='Use all branches instead of prompting for branches via fzf')
    common_parser.add_argument(
        '-b',
        '--branches',
        nargs='+',
        help='List of branches to use instead of prompting for branches via fzf')
    common_parser.add_argument('-C',
                               '--directory',
                               default=Path.cwd(),
                               help=f"Directory to run commands in (default: {Path.cwd()})",
                               type=Path)
    common_parser.add_argument('-d',
                               '--dry-run',
                               action='store_true',
                               help='Only print what would be done')
    common_parser.add_argument('--no-tags',
                               action='store_true',
                               help='Do not work on tags in addition to branches')

    clean_parser = subparser.add_parser('clean', help='Clean b4 branches', parents=[common_parser])
    clean_parser.add_argument('-r',
                              '--remote-only',
                              action='store_true',
                              help='Only consider remote branches when selecting and cleaning')

    subparser.add_parser('push', help='Push b4 branches to kernel.org', parents=[common_parser])

    return parser.parse_args()


def push_branch(directory, branch, tags, arguments):
    remote_branches = get_remote_b4_branches()

    if branch in remote_branches:
        lib.utils.print_yellow(f"{branch} already exists on remote, skipping...")
    else:
        push_cmd = ['push', '--set-upstream', 'korg', f"{branch}:{branch}"]
        if arguments.dry_run:
            lib.utils.print_cmd(['git', '-C', directory, *push_cmd])
        else:
            lib.utils.call_git_loud(directory, push_cmd)

    for tag in tags:
        if tag in remote_branches.get(branch, []):
            lib.utils.print_yellow(f"{tag} already exists on remote, skipping...")
            continue

        push_cmd = ['push', 'korg', tag]
        if arguments.dry_run:
            lib.utils.print_cmd(['git', '-C', directory, *push_cmd])
        else:
            lib.utils.call_git_loud(directory, push_cmd)


if __name__ == '__main__':
    args = parse_arguments()

    repo = args.directory.resolve()

    if not Path(repo, 'Makefile').exists():
        raise RuntimeError(f"Derived directory ('{repo}') does not look like a Linux kernel tree?")

    all_branches = get_remote_b4_branches() if getattr(args, 'remote_only',
                                                       False) else get_b4_branches(repo)

    if args.all:
        selected_branches = all_branches
    elif args.branches:
        selected_branches = filter_branches(args.branches, all_branches)
    else:
        preview_cmd = [
            'git',
            '-C',
            str(repo),
            'log',
            'korg/{1}' if getattr(args, 'remote_only', False) else '{1}',
            '-40',
            "--pretty=format:'%C(auto)%h%d %s %C(black)%C(bold)%cr%Creset'",
            '--color=always',
            '--abbrev-commit',
            '--date=relative',
        ]
        add_fzf_args = ['--preview', ' '.join(preview_cmd)]
        if fzf_out := lib.utils.fzf('branches to work on', '\n'.join(all_branches), add_fzf_args):
            selected_branches = filter_branches(fzf_out, all_branches)
        else:
            lib.utils.print_yellow('No branches selected, exiting gracefully...')
            sys.exit(0)

    if args.no_tags:
        for key in selected_branches:
            selected_branches[key] = []

    if args.subcommand == 'clean':
        func = clean_branch
    elif args.subcommand == 'push':
        func = push_branch
    else:
        raise RuntimeError(f"No function for {args.subcommand}?")
    for req_branch, branch_tags in selected_branches.items():
        func(repo, req_branch, branch_tags, args)
