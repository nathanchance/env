#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
import calendar
import datetime
import email
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zoneinfo

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils

# pylint: enable=wrong-import-position


# pylint: disable-next=invalid-name
def get_current_datetime(tz=None):
    return datetime.datetime.now(tz=tz)


def get_prev_or_next_datetime(val):
    if val == 'prev':
        pos = -1
    elif val == 'next':
        pos = 1
    else:
        raise RuntimeError(f"Invalid value in get_prev_or_next_datetime(): '{val}'")

    current = get_current_datetime()
    month = current.month + pos
    year = current.year

    if month > 12:
        month -= 12
        year += 1
    elif month < 1:
        month += 12
        year -= 1

    return datetime.datetime.strptime(f"{month} {year}", '%m %Y')


def get_next_datetime():
    return get_prev_or_next_datetime('next')


def get_prev_datetime():
    return get_prev_or_next_datetime('prev')


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


def get_monthly_report_path(date):
    return Path(get_report_worktree(), 'content/posts', get_report_file(date))


def get_yearly_report_path(year):
    return Path(get_report_repo(), f"content/posts/{year}-cbl-retrospective.md")


def get_report_repo():
    return Path(os.environ['GITHUB_FOLDER'], 'hugo-files')


def get_report_worktree():
    return Path(os.environ['CBL'], 'current-report')


def git(repo, cmd, capture_output=True, check=True, env=None, show_command=True):
    if not shutil.which('git'):
        raise RuntimeError('git could not be found!')
    command = ['git', '-C', repo, *cmd]
    if show_command:
        lib.utils.print_cmd(command)
    if env:
        env = os.environ.copy() | env
    return subprocess.run(command, capture_output=capture_output, check=check, env=env, text=True)


def git_check_success(repo, cmd):
    return git(repo, cmd, check=False, show_command=False).returncode == 0


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
    finalize_parser.add_argument('-P',
                                 '--prev-month',
                                 action='store_true',
                                 help='Target previous month as opposed to current month')
    finalize_parser.add_argument('-r',
                                 '--rebase',
                                 action='store_true',
                                 help='Rebase feature branch before merge')
    finalize_parser.add_argument('-R',
                                 '--remove-worktree',
                                 action='store_true',
                                 help='Remove worktree')
    finalize_parser.set_defaults(func=finalize_report)

    generate_parser = subparsers.add_parser('generate', help='Generate line items automatically')
    generate_parser.add_argument('type',
                                 choices=['mail', 'patch', 'pr'],
                                 help='Type of item to generate')
    generate_parser.set_defaults(func=generate_item)

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
    update_parser.add_argument('-P',
                               '--prev-month',
                               action='store_true',
                               help='Target previous month as opposed to current month')
    update_parser.set_defaults(func=update_report)

    yearly_parser = subparsers.add_parser('yearly',
                                          help='Generate yearly ClangBuiltLinux retrospective')
    yearly_parser.add_argument('-y',
                               '--year',
                               default=datetime.datetime.now().year,
                               help='Year of report (default: current year)',
                               type=int)
    yearly_parser.set_defaults(func=yearly_report)

    return parser.parse_args()


def local_branch_exists(repo, branch):
    return git_check_success(repo, ['rev-parse', '--verify', branch])


def remote_branch_exists(repo, branch):
    return git_check_success(repo, ['ls-remote', '--exit-code', '--heads', 'origin', branch])


def generate_devices(devices):
    delim = ', '
    replace = ', and '
    return replace.join(delim.join(devices).rsplit(delim, 1))


def generate_item(args):
    item_type = args.type

    if item_type == 'mail':
        msg = email.message_from_string(sys.stdin.read())

        if not (subject := msg.get('Subject')):
            raise RuntimeError('Cannot find subject in headers?')
        if not (msgid := msg.get('Message-ID')):
            raise RuntimeError('Cannot find message-ID in headers?')

        # Transform <message-id> into message-id
        msgid = msgid.strip('<').rstrip('>')

        # Unwrap subject if necessary
        if '\n' in subject:
            subject = ''.join(subject.splitlines())

        print(f"* [`{subject}`](https://lore.kernel.org/{msgid}/)")

    elif item_type == 'patch':
        if not Path('Makefile').exists():
            raise RuntimeError('Not in a kernel tree?')

        proc = subprocess.run(['b4', 'prep', '--show-info'],
                              capture_output=True,
                              check=True,
                              text=True)
        info = dict(map(str.strip, item.split(':', 1)) for item in proc.stdout.splitlines())
        commits = [key for key in info if key.startswith('commit-')]
        series = [key for key in info if key.startswith('series-v')]

        title = info[commits[0] if len(commits) == 1 else 'cover-subject']
        links = {
            item.rsplit('-', 1)[-1]: f"https://lore.kernel.org/{info[item].rsplit(' ', 1)[-1]}/"
            for item in series
        }
        md_links = [f"[`{key}`]({links[key]})" for key in sorted(links)]

        print(f"  * `{title}` ({', '.join(md_links)})")

    elif item_type == 'pr':
        proc = subprocess.run(['gh', 'pr', 'view', '--json', 'title,url'],
                              capture_output=True,
                              check=True,
                              text=True)
        gh_json = json.loads(proc.stdout)

        print(f"* [`{gh_json['title']}`]({gh_json['url']})")

    else:
        raise ValueError(f"Unhandled item type ('{item_type}')")


def create_monthly_report_file(report_file, report_date):
    title = f"{report_date.strftime('%B %Y')} ClangBuiltLinux Work"
    date = report_date.strftime('%Y-%m-%dT%H:%M:%S%z')
    # yapf: disable
    devices = [
        'a Raspberry Pi 4',
        'a Raspberry Pi 3',
        'a SolidRun Honeycomb LX2',
        'an Ampere Altra Developer Platform',
        'two Intel-based desktops',
        'an AMD-based desktop',
        'an Intel-based laptop',
    ]
    links = {
        'aosp_llvm': "[AOSP's distribution of LLVM](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/)",
        'google': '[Google](https://www.google.com/)',
        'lf': '[the Linux Foundation](https://www.linuxfoundation.org)',
        'linux_next': '[linux-next](https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/)',
        'lore': '[lore.kernel.org](https://lore.kernel.org/all/?q=f:nathan@kernel.org)',
        'sponsor': '[sponsoring my work](https://www.linuxfoundation.org/press/press-release/google-funds-linux-kernel-developers-to-focus-exclusively-on-security)',
        'tuxmake': '[TuxMake](https://tuxmake.org)',
        'werror': '[all developers should be using `CONFIG_WERROR`](https://lore.kernel.org/r/CAHk-=wifoM9VOp-55OZCRcO9MnqQ109UTuCiXeZ-eyX_JcNVGg@mail.gmail.com/)',
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
        '* Build errors: These are patches to fix various build errors that'
        ' I found through testing different configurations with LLVM or '
        'were exposed by our continuous integration setup. The kernel needs'
        ' to build in order to be run :)'                                  '\n'
                                                                           '\n'
        '  * `` ([`v1`]())'                                                '\n'
                                                                           '\n'
        '* Downstream fixes: These are fixes and improvements that occur in'
        ' a downstream Linux tree, such as Android or ChromeOS, which our '
        'continuous integration regularly tests.'                          '\n'
                                                                           '\n'
        '  * `` ([`v1`]())'                                                '\n'
                                                                           '\n'
        '* Miscellaneous fixes and improvements: These are fixes and '
        "improvements that don't fit into a particular category but are "
        'important to ClangBuiltLinux.'                                    '\n'
                                                                           '\n'
        '  * `` ([`v1`]())'                                                '\n'
                                                                           '\n'
        '* Stable backports and fixes: It is important to make sure that '
        'the stable trees are as free from issues as possible, as those are'
        ' the trees that devices and users use; for example, Android and '
        'Chrome OS regularly merge from stable, so if there is a problem '
        'that will impact those trees that we fixed in mainline, it should '
        'be backported.'                                                   '\n'
                                                                           '\n'
        '  * `` ([`v1`]())'                                                '\n'
                                                                           '\n'
        '* Warning fixes: These are patches to fix various warnings that '
        'appear with LLVM. I used to go into detail about the different '
        'warnings and what they mean, but the important takeaway for this '
        'section is that the kernel should build warning free, as '
        f"{links['werror']}, which will turn these all into failures. Maybe"
        ' these should be in the build failures section...'                '\n'
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
        '* [``](https://lore.kernel.org/)'                                 '\n'
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
        '* [``](https://lore.kernel.org/)'                                 '\n'
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

    report_file.write_text(template, encoding='utf-8')


def get_yearly_commits(year, source, branch='main', git_log_args=None, update=True):
    if update:
        subprocess.run(['git', 'remote', 'update', '--prune', 'origin'],
                       capture_output=True,
                       check=True,
                       cwd=source)
    git_log_cmd = [
        'git',
        'log',
        '--format=%H %s',
        '--no-merges',
        f"--since-as-filter=Jan 1, {year}",
        f"--until=Jan 1, {year + 1}",
        f"origin/{branch}",
    ]
    if git_log_args:
        git_log_cmd += git_log_args
    else:
        git_log_cmd.append('--author=Nathan Chancellor')
    git_log_output = subprocess.run(git_log_cmd,
                                    capture_output=True,
                                    check=True,
                                    cwd=source,
                                    text=True)

    return dict(item.split(' ', 1) for item in git_log_output.stdout.splitlines())


def generate_html_commit_section(commits, repo):
    if 'github' in repo:
        commits_view = 'commit/'
    elif 'gitlab' in repo:
        commits_view = '-/commit/'
    elif 'kernel.org' in repo:
        commits_view = ''
    else:
        raise RuntimeError(f"Don't know how to handle repo URL: {repo}")
    return ''.join([
        f'<a href="{repo}/{commits_view}{sha}">{sha[1:14]}</a> ("{title}")</br>\n'
        for sha, title in commits.items()
    ])


def create_yearly_report_file(report_file, report_date, year):
    title = f"{year} ClangBuiltLinux Retrospective"
    date = report_date.strftime('%Y-%m-%dT%H:%M:%S%z')

    # yapf: disable
    linux_link = 'https://git.kernel.org/linus'
    llvm_link = 'https://github.com/llvm/llvm-project'
    boot_utils_link = 'https://github.com/ClangBuiltLinux/boot-utils'
    ci_link = 'https://github.com/ClangBuiltLinux/continuous-integration2'
    tc_build_link = 'https://github.com/ClangBuiltLinux/tc-build'
    tuxmake_link = 'https://gitlab.com/Linaro/tuxmake'
    links = {
        'boot_utils_log': f'<a href="{boot_utils_link}/commits/main?author=nathanchance">GitHub</a>',
        'ci_log': f'<a href="{ci_link}/commits/main?author=nathanchance">GitHub</a>',
        'gh_org': '[our GitHub organization](https://github.com/ClangBuiltLinux)',
        'google': '[Google](https://www.google.com/)',
        'last_retro': f"[Just like I did last year](/posts/{year - 1}-cbl-retrospective/)",
        'lf': '[the Linux Foundation](https://www.linuxfoundation.org)',
        'linux_log': '<a href="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/?qt=author&q=Nathan+Chancellor">git.kernel.org</a>',
        'llvm_log': f'<a href="{llvm_link}/commits/main?author=nathanchance">GitHub</a>',
        'sponsor': '[sponsoring my work](https://www.linuxfoundation.org/press/press-release/google-funds-linux-kernel-developers-to-focus-exclusively-on-security)',
        'tc_build_log': f'<a href="{tc_build_link}/commits/main?author=nathanchance">GitHub</a>',
        'testimonial': '[which developers do appreciate](https://lore.kernel.org/YtsY5xwmlQ6kFtUz@google.com/)',
        'tuxmake': f"[TuxMake]({tuxmake_link})",
        'tuxmake_log': f'<a href="{tuxmake_link}/-/commits/master?author=Nathan%20Chancellor">GitLab</a>',
    }

    linux_src = Path(os.environ['CBL_SRC'], 'linux-next')
    linux_gyc_kwargs = {
        'year': year,
        'source': linux_src,
        'branch': 'master',
    }
    linux_commits = get_yearly_commits(**linux_gyc_kwargs)
    linux_commit_links = generate_html_commit_section(linux_commits, linux_link)
    # Updating the Linux repo is no longer necessary after the initial update
    linux_gyc_kwargs['update'] = False
    # We could generate linux_rep_rev_tst from the combination of the other
    # three but then the commits will not be in order as they would be from git
    # log, so just generate a fourth dictionary *shrugs*
    linux_rep_rev_tst = get_yearly_commits(**linux_gyc_kwargs, git_log_args=['--extended-regexp', '--grep=(Report|Review|Test)ed-by: Nathan Chancellor'])
    linux_rep_rev_tst_links = generate_html_commit_section(linux_rep_rev_tst, linux_link)
    linux_rep = get_yearly_commits(**linux_gyc_kwargs, git_log_args=['--grep=Reported-by: Nathan Chancellor'])
    linux_rev = get_yearly_commits(**linux_gyc_kwargs, git_log_args=['--grep=Reviewed-by: Nathan Chancellor'])
    linux_tst = get_yearly_commits(**linux_gyc_kwargs, git_log_args=['--grep=Tested-by: Nathan Chancellor'])

    llvm_src = Path(os.environ['CBL_SRC'], 'llvm-project')
    llvm_commits = get_yearly_commits(year, llvm_src)
    llvm_links = generate_html_commit_section(llvm_commits, llvm_link)

    boot_utils_src = Path(os.environ['CBL_GIT'], 'boot-utils')
    boot_utils_commits = get_yearly_commits(year, boot_utils_src)
    boot_utils_links = generate_html_commit_section(boot_utils_commits, boot_utils_link)

    ci_src = Path(os.environ['CBL_GIT'], 'continuous-integration2')
    ci_commits = get_yearly_commits(year, ci_src)
    ci_links = generate_html_commit_section(ci_commits, ci_link)

    tc_build_src = Path(os.environ['CBL_GIT'], 'tc-build')
    tc_build_commits = get_yearly_commits(year, tc_build_src)
    tc_build_links = generate_html_commit_section(tc_build_commits, tc_build_link)

    tuxmake_src = Path(os.environ['CBL_SRC'], 'tuxmake')
    tuxmake_commits = get_yearly_commits(year, tuxmake_src, branch='master')
    tuxmake_links = generate_html_commit_section(tuxmake_commits, tuxmake_link)

    report_links = [f"- [{month} {year}](/posts/{month.lower()}-{year}-cbl-work/)" for month in calendar.month_name if month]

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
        f"{links['last_retro']}, I want to do a yearly report/retrospective"
        f" for {year} to look at what I (and the whole ClangBuiltLinux team"
        ' in some cases) accomplished. I do monthly reports but looking at '
        'a high level across the year helps put things into perspective and'
        ' drive improvements going into the new year.'                     '\n'
                                                                           '\n'
        '## Linux kernel'                                                  '\n'
                                                                           '\n'
        f"This year, I had {len(linux_commits)} commits accepted into "
        f"maintainer trees (not all will be merged into mainline in {year} "
        f"but they were written and added in maintainer trees in {year}). "
        'They can be viewed on the web or by running the following command '
        'in an up-to-date Linux repository locally:'                       '\n'
                                                                           '\n'
        '```'                                                              '\n'
        '$ git log \\'                                                     '\n'
        '    --author=\'Nathan Chancellor\' \\'                            '\n'
        '    --oneline \\'                                                 '\n'
        f"    --since-as-filter='Jan 1, {year}' \\"                        '\n'
        f"    --until='Jan 1, {year + 1}' \\"                              '\n'
        '    origin/master'                                                '\n'
        '```'                                                              '\n'
                                                                           '\n'
        'A similar command will be used to generate all following commit '
        'logs, which are included for convenience behind some collapsible '
        'Markdown with links.'                                             '\n'
                                                                           '\n'
        '<details>'                                                        '\n'
        '<summary>'
        f"Kernel contributions in {year} ({links['linux_log']})"
        '</summary>'                                                       '\n'
        '<p><code>'                                                        '\n'
        f"{linux_commit_links}"
        '</code></p>'                                                      '\n'
        '</details></br>'                                                  '\n'
                                                                           '\n'
        '<INSERT EXPLANATION HERE>'                                        '\n'
                                                                           '\n'
        'It is important to keep in mind that sending patches is only part'
        ' of the development process. The others are reporting problems and'
        ' testing and reviewing solutions to those problems. The kernel '
        'keeps track of these through particular tags: `Reported-by`, '
        f"`Reviewed-by`, and `Tested-by`. In {year}, I provided those tags "
        f"on {len(linux_rep_rev_tst)} patches. The break down of patches "
        'that contained:'                                                  '\n'
                                                                           '\n'
        f"- `Reported-by`: {len(linux_rep)}"                               '\n'
        f"- `Reviewed-by`: {len(linux_rev)}"                               '\n'
        f"- `Tested-by`: {len(linux_tst)}"                                 '\n'
                                                                           '\n'
        'A full list of those commits are below, generated with the '
        'following command in an up-to-date Linux checkout:'               '\n'
                                                                           '\n'
        '```'                                                              '\n'
        '$ git log \\'                                                     '\n'
        '    --extended-regexp \\'                                         '\n'
        '    --grep=\'(Report|Review|Test)ed-by: Nathan Chancellor\' \\'   '\n'
        '    --oneline \\'                                                 '\n'
        f"    --since-as-filter='Jan 1, {year}' \\"                        '\n'
        f"    --until='Jan 1, {year + 1}' \\"                              '\n'
        '    origin/master'                                                '\n'
        '```'                                                              '\n'
                                                                           '\n'
        '<details>'                                                        '\n'
        '<summary>'
        f"<code>Reported-by, Reviewed-by, and Tested-by</code> in {year}"
        '</summary>'                                                       '\n'
        '<p><code>'                                                        '\n'
        f"{linux_rep_rev_tst_links}"
        '</code></p>'                                                      '\n'
        '</details></br>'                                                  '\n'
                                                                           '\n'
                                                                           '\n'
        '## LLVM'                                                          '\n'
                                                                           '\n'
        'I am far from a large LLVM contributor but I do have occasional '
        'patches there as part of this work. This year, I had '
        f"{len(llvm_commits)} patches to LLVM. <INSERT EXPLANATION HERE>"  '\n'
                                                                           '\n'
        '<details>'                                                        '\n'
        '<summary>'
        f"LLVM contributions in {year} ({links['llvm_log']})"
        '</summary>'                                                       '\n'
        '<p><code>'                                                        '\n'
        f"{llvm_links}"
        '</code></p>'                                                      '\n'
        '</details></br>'                                                  '\n'
                                                                           '\n'
                                                                           '\n'
        '## Tooling'                                                       '\n'
                                                                           '\n'
        f"We have a few different repositories in {links['gh_org']} that we"
        ' use for testing and development, which I call "tooling". Tooling '
        'is very important for repetitive tasks or tasks where you want to '
        'take the human out of the equation so that mistakes are less '
        'likely, such as a bisect. Additionally, there are some other '
        f"repositories that we rely on, like {links['tuxmake']}, that I "
        'consistently contribute to.'                                      '\n'
                                                                           '\n'
        '<INSERT EXPLANATION HERE>'                                        '\n'
                                                                           '\n'
        'Like previously, I have included the `git log` output with direct '
        'links to commits, along with a web link to browse the history '
        'there.'                                                           '\n'
                                                                           '\n'
        '<details>'                                                        '\n'
        f"<summary>boot-utils ({links['boot_utils_log']})</summary>"       '\n'
        '<p><code>'                                                        '\n'
        f"{boot_utils_links}"
        '</code></p>'                                                      '\n'
        '</details></br>'                                                  '\n'
                                                                           '\n'
        '<details>'                                                        '\n'
        f"<summary>continuous-integration2 ({links['ci_log']})</summary>"  '\n'
        '<p><code>'                                                        '\n'
        f"{ci_links}"
        '</code></p>'                                                      '\n'
        '</details></br>'                                                  '\n'
                                                                           '\n'
        '<details>'                                                        '\n'
        f"<summary>tc-build ({links['tc_build_log']})</summary>"           '\n'
        '<p><code>'                                                        '\n'
        f"{tc_build_links}"
        '</code></p>'                                                      '\n'
        '</details></br>'                                                  '\n'
                                                                           '\n'
        '<details>'                                                        '\n'
        f"<summary>TuxMake ({links['tuxmake_log']})</summary>"             '\n'
        '<p><code>'                                                        '\n'
        f"{tuxmake_links}"
        '</code></p>'                                                      '\n'
        '</details></br>'                                                  '\n'
                                                                           '\n'
        '## Behind the scenes'                                             '\n'
                                                                           '\n'
        'There are always things that require time but do not always show '
        'tangible results. There are three things that I think fall under '
        'this category:'                                                   '\n'
                                                                           '\n'
        '- __Issue tracker management:__ Keeping a clean and accurate issue'
        ' tracker is critical for few reason.'                             '\n'
        '  1. It gives a good high level overview of the "health" of the '
        'project. We want our issue tracker to be an accurate '
        'representation of how much help we need (since we always need '
        'it...)'                                                           '\n'
        '  2. It helps assign priority to certain issues. If we have a lot '
        'of open but resolved issues, it can be hard to decide what needs '
        'to be worked on next.'                                            '\n'
        '  3. The issue tracker is a wonderful historical reference. We use'
        ' the issue tracker to keep track of mailing list posts and such so'
        ' it is important that those links are as acccurate as possible and'
        ' have as much information as possible in case we have to look back'
        ' five years later to wonder why we did something the way that we '
        'did.'                                                             '\n'
        "- __Mailing list reading:__ We are not Cc'd on every issue related"
        " to `clang`, even though sometimes it is the compiler's problem or"
        ' a known difference between the toolchains that we have already '
        'figured out. By monitoring the mailing list for certain phrases, '
        'we can provide assistance without being initially notified, '
        f"{links['testimonial']}."'\n'
        '- __Hardware testing:__ Every linux-next release, I built and boot'
        ' kernels on a variety of hardware to test for issues, as some '
        'problems only show up on bare metal or with a full distribution. '
        'I wrote a script to drive a full distribution QEMU on a variety of'
        ' architectures to make some of that testing and debugging easier '
        'but bare metal is always an important testing target, since that '
        'is where the kernel will run the majority of the time.'           '\n'
                                                                           '\n'
                                                                           '\n'
        '## Special thanks'                                                '\n'
                                                                           '\n'
        f"Special thanks to {links['google']} and {links['lf']} for "
        f"{links['sponsor']}. I am in a very fortunate position thanks to "
        'the work of many great and suppportive folks at those '
        'organizations and I look forward to continuing to contribute under'
        f" this umbrella for {year + 1}!"                                  '\n'
                                                                           '\n'
        'To view individual monthly reports, click on one of the links '
        'below:'                                                           '\n'
                                                                           '\n'
        + '\n'.join(report_links) +                                        '\n'
    )
    # yapf: enable

    report_file.write_text(template, encoding='utf-8')


def finalize_report(args):
    # Get the source and destination paths and branch based on current time
    repo = get_report_repo()

    if not (worktree := get_report_worktree()).exists():
        raise RuntimeError(f"{repo} does not exist when finalizing?")

    # Rebase changes if requested
    if args.rebase or args.all:
        git(worktree, ['rebase', '-i', '--autosquash', 'origin/main'],
            env={'GIT_SEQUENCE_EDITOR': shutil.which('true')})

    # Get branch based on user's request
    date = get_prev_datetime() if args.prev_month else get_current_datetime()

    # Merge branch into main
    branch = get_report_branch(date)
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
            raise RuntimeError(f"{worktree} already exists, run 'finalize' or 'new' without '-A'?")

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
            raise RuntimeError(f"{worktree} does not exist when creating report file?")

        report = get_monthly_report_path(date)
        if not report.exists():
            report_date = get_initial_report_date()
            commit_title = f"content/posts: ClangBuiltLinux work in {report_date.strftime('%B')} {report_date.year}"
            commit_date = report_date.strftime('%a %b %d %H:%M:%S %Y %z')

            create_monthly_report_file(report, report_date)
            git(worktree, ['add', report])
            git(worktree, ['commit', '-m', commit_title, '--date', commit_date])


def update_report(args):
    if not (worktree := get_report_worktree()).exists():
        raise RuntimeError(f"{worktree} does not exist when updating?")

    # Get branch based on user's request
    date = get_prev_datetime() if args.prev_month else get_current_datetime()

    if not (report := get_monthly_report_path(date)).exists():
        raise RuntimeError(f"{report} does not exist when updating?")

    if args.edit or args.all:
        if not (editor := shutil.which(os.environ.get('EDITOR', 'vim'))):
            raise RuntimeError("$EDITOR not set or vim could not be found on your system!")

        subprocess.run([editor, report], check=True)

    if args.commit or (args.all and args.commit):
        git(worktree, ['add', report])
        git(worktree, ['c', '--fixup', args.commit])
    if args.push or args.all:
        git(worktree, ['push'])


def yearly_report(args):
    repo = get_report_repo()
    report = get_yearly_report_path(args.year)
    if not report.exists():
        report_date = get_initial_report_date()
        commit_title = f"content/posts: {args.year} ClangBuiltLinux retrospective"
        commit_date = report_date.strftime('%a %b %d %H:%M:%S %Y %z')

        create_yearly_report_file(report, report_date, args.year)
        git(repo, ['add', report])
        git(repo, ['commit', '-m', commit_title, '--date', commit_date])


if __name__ == '__main__':
    main_args = parse_parameters()
    main_args.func(main_args)
