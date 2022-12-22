#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
import os

import lib_kernel


def parse_arguments():
    parser = ArgumentParser(description='A make wrapper for building Linux kernels')

    parser.add_argument('-C', '--directory', help='Mirrors the equivalent make argument')
    parser.add_argument('--no-ccache', action='store_true', help='Disable the use of ccache')
    parser.add_argument('-p',
                        '--prepend-to-path',
                        help='Prepend specified directories to PATH',
                        nargs='+')
    parser.add_argument('-j', '--jobs', default=os.cpu_count(), help='Number of jobs', type=int)
    parser.add_argument('-v', '--verbose', action='store_true', help='Do a more verbose build')
    parser.add_argument('make_args', help='Make variables and targets', nargs='*')

    return parser.parse_args()


def prepend_to_path(paths):
    if not paths:
        return
    for path in paths:
        if not Path(path).exists():
            raise Exception(f"Requested path addition ('{path}') does not exist?")
    os.environ['PATH'] = os.pathsep.join(paths) + os.pathsep + os.environ['PATH']


if __name__ == '__main__':
    args = parse_arguments()

    prepend_to_path(args.prepend_to_path)

    variables = {}
    targets = []
    for arg in args.make_args:
        if '=' in arg:
            variables.update([arg.split('=', 1)])
        else:
            # Basically an ordered set
            if arg not in targets:
                targets.append(arg)

    lib_kernel.kmake(variables,
                     targets,
                     ccache=(not args.no_ccache),
                     directory=args.directory,
                     jobs=args.jobs,
                     silent=(not args.verbose))
