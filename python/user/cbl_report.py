#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

from argparse import ArgumentParser
import datetime
import os
from pathlib import Path
import shutil
import subprocess
import zoneinfo


# pylint: disable-next=invalid-name
def get_current_datetime(tz=None):
    return datetime.datetime.now(tz=tz)


def get_next_datetime():
    current = get_current_datetime()
    month = current.month + 1
    year = current.year
    if month > 12:
        month -= 12
        year += 1
    return datetime.datetime.strptime(f"{month} {year}", '%m %Y')


def get_month_year(date):
    return date.strftime('%B-%Y').lower()


def get_report_branch(date):
    return 'cbl-' + get_month_year(date)


def get_initial_report_date():
    year = int(input("Input initial report year (YYYY): "))
    month = int(input("Input initial report month (MM): "))
    day = int(input("Input initial report day (DD): "))

    date = datetime.datetime(year,
                             month,
                             day,
                             hour=19,
                             minute=30,
                             tzinfo=zoneinfo.ZoneInfo('US/Eastern'))

    return date.astimezone(zoneinfo.ZoneInfo('US/Arizona'))


def get_report_file(date):
    return get_report_name(date) + '.md'


def get_report_name(date):
    return get_month_year(date) + '-cbl-work'


def get_report_path(date):
    return get_report_worktree().joinpath('content', 'posts', get_report_file(date))


def get_report_repo():
    return Path(os.environ['GITHUB_FOLDER'], 'hugo-files')


def get_report_worktree():
    return Path(os.environ['CBL'], 'current-report')


def git(repo, cmd, check=True):
    if not shutil.which('git'):
        raise Exception('git could not be found!')
    return subprocess.run(['git', '-C', repo] + cmd, capture_output=True, check=check, text=True)


def git_check_success(repo, cmd):
    return git(repo, cmd, check=False).returncode == 0


def parse_parameters():
    parser = ArgumentParser()
    subparsers = parser.add_subparsers(help='Action to perform', required=True)

    finalize_parser = subparsers.add_parser(
        'finalize', help='Merge report branch into main branch then delete branch and worktree')
    finalize_parser.add_argument('-a', '--all', action='store_true', help='Do everything')
    finalize_parser.add_argument('-d',
                                 '--delete-branch',
                                 action='store_true',
                                 help='Delete report branch')
    finalize_parser.add_argument('-m',
                                 '--merge',
                                 action='store_true',
                                 help='Merge report branch in main branch')
    finalize_parser.add_argument('-p',
                                 '--push',
                                 action='store_true',
                                 help='Push main branch after merge')
    finalize_parser.add_argument('-r',
                                 '--rebase',
                                 action='store_true',
                                 help='Rebase feature branch before merge')
    finalize_parser.add_argument('-R',
                                 '--remove-worktree',
                                 action='store_true',
                                 help='Remove worktree')
    finalize_parser.set_defaults(func=finalize_report)

    new_parser = subparsers.add_parser(
        'new',
        help='Create a new branch, worktree, and report file for ClangBuiltLinux monthly report')
    new_parser.add_argument('-a', '--all', action='store_true', help='Do everything')
    new_parser.add_argument('-A',
                            '--add-worktree',
                            action='store_true',
                            help='Create a new branch and worktree')
    new_parser.add_argument('-c',
                            '--create-report',
                            action='store_true',
                            help='Create a new report file')
    new_parser.add_argument('-n',
                            '--next-month',
                            action='store_true',
                            help='Target next month as opposed to current month')
    new_parser.add_argument('-p',
                            '--push',
                            action='store_true',
                            help='Push report branch if it does not exist remotely')
    new_parser.add_argument('-u',
                            '--update',
                            action='store_true',
                            help='Update repository before checking for remote branch')
    new_parser.set_defaults(func=new_report)

    update_parser = subparsers.add_parser('update',
                                          help='Update current ClangBuiltLinux monthly report')
    update_parser.add_argument('-a', '--all', action='store_true', help='Do everything')
    update_parser.add_argument('-c', '--commit', help='Hash of commit to "fix up"', type=str)
    update_parser.add_argument('-e', '--edit', action='store_true', help='Edit report file')
    update_parser.add_argument('-p', '--push', action='store_true', help='Push update after commit')
    update_parser.set_defaults(func=update_report)

    return parser.parse_args()


def local_branch_exists(repo, branch):
    return git_check_success(repo, ['rev-parse', '--verify', branch])


def remote_branch_exists(repo, branch):
    return git_check_success(repo, ['ls-remote', '--exit-code', '--heads', 'origin', branch])


def generate_devices(devices):
    delim = ', '
    replace = ', and '
    return replace.join(delim.join(devices).rsplit(delim, 1))


def create_report_file(report_file, report_date):
    title = f"{report_date.strftime('%B %Y')} ClangBuiltLinux Work"
    date = report_date.strftime('%Y-%m-%dT%H:%M:%S%z')
    # yapf: disable
    devices = [
        'a Raspberry Pi 4',
        'a Raspberry Pi 3',
        'a SolidRun Honeycomb LX2',
        'an Intel-based desktop',
        'an AMD-based desktop',
        'an Intel-based laptop'
    ]
    links = {
        'aosp_llvm': "[AOSP's distribution of LLVM](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/)",
        'google': '[Google](https://www.google.com/)',
        'lf': '[the Linux Foundation](https://linuxfoundation.org/)',
        'linux_next': '[linux-next](https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/)',
        'lore': '[lore.kernel.org](https://lore.kernel.org/all/?q=f:nathan@kernel.org)',
        'sponsor': '[sponsoring my work](https://linuxfoundation.org/en/press-release/google-funds-linux-kernel-developers-to-focus-exclusively-on-security/)',
        'tuxmake': '[TuxMake](https://tuxmake.org)'
    }
    # Yes, this is Markdown in Python :)
    template = (
        '---'                                                              '\n'
        f"title: {title}"                                                  '\n'
        f"date: {date}"                                                    '\n'
        'toc: false'                                                       '\n'
        'images:'                                                          '\n'
        'tags:'                                                            '\n'
        '  - clangbuiltlinux'                                              '\n'
        '  - linux'                                                        '\n'
        '  - linuxfoundation'                                              '\n'
        '  - maintainer'                                                   '\n'
        '---'                                                              '\n'
                                                                           '\n'
        'Occasionally, I will forget to link something from the mailing '
        'list in this post. To see my full mailing list activity (patches, '
        f"reviews, and reports), you can view it on {links['lore']}."      '\n'
                                                                           '\n'
        '## Linux kernel patches'                                          '\n'
                                                                           '\n'
        '* ``:'                                                            '\n'
                                                                           '\n'
        '  * `` ([`v1`]())'                                                '\n'
                                                                           '\n'
                                                                           '\n'
                                                                           '\n'
        '## LLVM patches'                                                  '\n'
                                                                           '\n'
        '* [``]()'                                                         '\n'
                                                                           '\n'
                                                                           '\n'
                                                                           '\n'
        '## Patch review and input'                                        '\n'
                                                                           '\n'
        'For the next sections, I link directly to my first response in the'
        ' thread when possible but there are times where the link is to the'
        ' main post. My responses can be seen inline by going to the bottom'
        ' of the thread and clicking on my name.'                          '\n'
                                                                           '\n'
        'Reviewing patches that are submitted is incredibly important, as '
        'it helps ensure good code quality due to catching mistakes before '
        'the patches get accepted and it can help get patches accepted '
        'faster, as some maintainers will blindly pick up patches that '
        'have been reviewed by someone that they trust.'                   '\n'
                                                                           '\n'
        '* [``]()'                                                         '\n'
                                                                           '\n'
                                                                           '\n'
                                                                           '\n'
        '## Issue triage, input, and reporting'                            '\n'
                                                                           '\n'
        'The unfortunate thing about working at the intersection of two '
        'projects is we will often find bugs that are not strictly related '
        'to the project, which require some triage and reporting back to '
        'the original author of the breakage so that they can be fixed and '
        'not impact our own testing. Some of these bugs fall into that '
        'category while others are issues strictly related to this '
        'project.'                                                         '\n'
                                                                           '\n'
        '* [``]()'                                                         '\n'
                                                                           '\n'
                                                                           '\n'
                                                                           '\n'
        '## Tooling improvements'                                          '\n'
                                                                           '\n'
        'These are changes to various tools that we use, such as our '
        'continuous integration setup, booting utilities, toolchain '
        'building scripts, or other closely related projects such as '
        f"{links['aosp_llvm']} and {links['tuxmake']}."                    '\n'
                                                                           '\n'
        '* [``]()'                                                         '\n'
                                                                           '\n'
                                                                           '\n'
                                                                           '\n'
        '## Behind the scenes'                                             '\n'
                                                                           '\n'
        f"* Every day that there is a new {links['linux_next']} release, "
        'I rebase and build a few different kernel trees then boot and '
        'runtime test them on several different machines, including '
        f"{generate_devices(devices)}. This is not always visible because I"
        ' do not report anything unless there is something broken but it '
        'can take up to a few hours each day, depending on the amount of '
        'churn and issues uncovered.'                                      '\n'
                                                                           '\n'
                                                                           '\n'
                                                                           '\n'
        '## Special thanks'                                                '\n'
                                                                           '\n'
        f"Special thanks to {links['google']} and {links['lf']} for "
        f"{links['sponsor']}."                                             '\n'
    )
    # yapf: enable
    with open(report_file, 'w', encoding="utf-8") as file:
        file.write(template)


def finalize_report(args):
    # Get the source and destination paths and branch based on current time
    repo = get_report_repo()
    worktree = get_report_worktree()

    if not worktree.exists():
        raise Exception(f"{repo} does not exist when finalizing?")

    # Rebase changes if requested
    if args.rebase or args.all:
        git(worktree, ['rebase', '-i', '--autosquash', 'origin/main'])

    # Merge branch into main
    branch = get_report_branch(get_current_datetime())
    if args.merge or args.all:
        git(repo, ['merge', branch])

    # Remove worktree ('--force' due to submodules)
    if args.remove_worktree or args.all:
        git(repo, ['worktree', 'remove', '--force', worktree])

    # Delete branch locally and remotely if necessary
    if args.delete_branch or args.all:
        git(repo, ['branch', '--delete', '--force', branch])
        if remote_branch_exists(repo, branch):
            git(repo, ['push', 'origin', f":{branch}"])

    # Push main if requested
    if args.push or args.all:
        git(repo, ['push'])


def new_report(args):
    # Get the source and destination paths
    repo = get_report_repo()
    worktree = get_report_worktree()

    # Get branch based on user's request
    date = get_next_datetime() if args.next_month else get_current_datetime()

    # Figure out 'git worktree add' arguments based on whether or not branch
    # exists locally, remotely, or not at all.
    if args.add_worktree or args.all:
        branch = get_report_branch(date)

        # Check for an existing worktree
        if worktree.exists():
            raise Exception(f"{worktree} already exists, run 'finalize' or 'new' without '-A'?")

        # Update source repo to ensure remote branch check is up to date
        if args.update or args.all:
            git(repo, ['remote', 'update', '--prune', 'origin'])

        push_to_remote = False
        worktree_add = ['worktree', 'add']
        if local_branch_exists(repo, branch):
            worktree_add += [worktree, branch]
        elif remote_branch_exists(repo, branch):
            worktree_add += ['-b', branch, '--track', worktree, f"origin/{branch}"]
        else:
            worktree_add += ['-b', branch, worktree, 'origin/main']
            push_to_remote = True

        # Create worktree
        git(repo, worktree_add)

        # Push new branch if needed
        if (args.push or args.all) and push_to_remote:
            git(worktree, ['push', '--set-upstream', 'origin', branch])

        # Update submodules, as that is how the theme is checked out
        git(worktree, ['submodule', 'update', '--init', '--recursive'])

    # Create new report file if necessary
    if args.create_report or args.all:
        # Make sure worktree exists in case I run 'new' without '-A'
        if not worktree.exists():
            raise Exception(f"{worktree} does not exist when creating report file?")

        report = get_report_path(date)
        if not report.exists():
            report_date = get_initial_report_date()
            commit_title = f"content/posts: ClangBuiltLinux work in {report_date.strftime('%B')} {report_date.year}"
            commit_date = report_date.strftime('%a %b %d %H:%M:%S %Y %z')

            create_report_file(report, report_date)
            git(worktree, ['add', report])
            git(worktree, ['commit', '-m', commit_title, '--date', commit_date])


def update_report(args):
    worktree = get_report_worktree()
    if not worktree.exists():
        raise Exception(f"{worktree} does not exist when updating?")

    report = get_report_path(get_current_datetime())
    if not report.exists():
        raise Exception(f"{report} does not exist when updating?")

    if args.edit or args.all:
        editor = shutil.which(os.environ['EDITOR'] if 'EDITOR' in os.environ else 'vim')
        if not editor:
            raise Exception("$EDITOR not set or vim could not be found on your system!")

        subprocess.run([editor, report], check=True)

    if args.commit or (args.all and args.commit):
        git(worktree, ['add', report])
        git(worktree, ['c', '--fixup', args.commit])
    if args.push or args.all:
        git(worktree, ['push'])


if __name__ == '__main__':
    main_args = parse_parameters()
    main_args.func(main_args)
