#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

import sys
from argparse import ArgumentParser
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils

# pylint: enable=wrong-import-position

parser = ArgumentParser(description='Generate Cc: lines for patch')
parser.add_argument(
    '-C',
    '--directory',
    default='.',
    help='Change into directory for operations (default: current working directory)')
parser.add_argument('path', help='Path to generate Cc: list for')
args = parser.parse_args()

if not (repo := Path(args.directory).resolve()).exists():
    raise RuntimeError(f"Provided repo ('{repo}') could not be found?")

if not (get_maint := Path(repo, 'scripts/get_maintainer.pl')).exists():
    raise RuntimeError(f"Provided repo ('{repo}') does not appear to be a kernel tree?")

if not (path := Path(repo, args.path)).exists():
    raise RuntimeError(f"Provided path ('{path}') could not be found in provided repo ('{repo}')?")

# Show raw scripts/get_maintainer.pl output, which can help with trimming up or
# modifying the list of addresses to send the patch to.
lib.utils.run([get_maint, path], cwd=repo)
print()

for addr in lib.utils.chronic([get_maint, '--no-n', '--no-rolestats', path],
                              cwd=repo).stdout.splitlines():
    print(f"Cc: {addr}")
