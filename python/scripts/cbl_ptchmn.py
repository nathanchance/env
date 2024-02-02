#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
import subprocess
import os
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable-next=wrong-import-position
import lib.utils


def git(directory, cmd, **kwargs):
    return subprocess.run(['git', *cmd],
                          capture_output=True,
                          check=True,
                          cwd=directory,
                          text=True,
                          **kwargs)


def git_loud(directory, cmd, **kwargs):
    lib.utils.print_cmd(['git', '-C', directory, *cmd])
    return git(directory, cmd, **kwargs)


def get_patches_folder(repo):
    branch = git(repo, ['bn']).stdout.strip()
    return Path(os.environ['GITHUB_FOLDER'], 'patches', repo.name, branch)


def parse_arguments():
    parser = ArgumentParser(description='Quilt-like patch management function for Linux')

    parser.add_argument('-C',
                        '--directory',
                        default=Path.cwd().resolve(),
                        help='Directory to run git commands in',
                        type=Path)

    mode_parser = parser.add_mutually_exclusive_group(required=True)
    mode_parser.add_argument('-s', '--sync', action='store_true', help='Sync patches to repo')
    mode_parser.add_argument('-a', '--apply', action='store_true', help='Apply patches from repo')

    return parser.parse_args()


def apply(repo, patches):
    git(repo, ['am', *patches])


def sync(repo, patches_output):
    if repo.name not in ('linux', 'linux-next') and 'linux-stable' not in repo.name:
        raise RuntimeError(f"Supplied repo ('{repo}, {repo.name}') is not supported by cbl_ptchmn!")

    if not (mfc := git(repo, ['mfc']).stdout.strip()):
        raise RuntimeError('My first commit could not be found?')

    # Generate a list of patches to remove. The Python documentation states
    # that it is unspecified to change the contents of a directory when using
    # Path.iterdir() to iterate over it.
    patches_to_remove = list(patches_output.iterdir())
    for item in patches_to_remove:
        item.unlink()

    fp_cmd = ['fp', f"--base={mfc}^", '-o', patches_output, f"{mfc}^..HEAD"]
    git_loud(repo, fp_cmd)

    status_cmd = ['--no-optional-locks', 'status', '-u', '--porcelain']
    if git(patches_output, status_cmd).stdout.strip():
        git(patches_output, ['aa'])

        sha = git(repo, ['sha']).stdout.strip()
        cmt_msg = f"patches: {repo.name}: {patches_output.name}: sync as of {sha}"
        git_loud(patches_output, ['c', '-m', cmt_msg])

        git(patches_output, ['push'])


if __name__ == '__main__':
    args = parse_arguments()

    if not Path(args.directory, 'Makefile').exists():
        raise RuntimeError(
            f"Supplied repository ('{args.directory}') does not appear to be a Linux kernel tree?")

    if not (patches_folder := get_patches_folder(args.directory)).exists():
        raise RuntimeError(f"Derived patches folder ('{patches_folder}') does not exist!")

    if args.apply:
        apply(args.directory, patches_folder.iterdir())
    if args.sync:
        sync(args.directory, patches_folder)
