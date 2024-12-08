#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
import subprocess
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position

parser = ArgumentParser(
    description=
    'Run command in "tmux new-window" with proper quoting to run in either host or container')
parser.add_argument('-c',
                    '--container',
                    action='store_const',
                    const='container',
                    dest='mode',
                    help='Run command in default distrobox container')
parser.add_argument('-H',
                    '--host',
                    action='store_const',
                    const='host',
                    dest='mode',
                    help='Run command on the host')
parser.add_argument('-d', '--detach', action='store_true', help='Do not switch to created window')
parser.add_argument('args', nargs='+', help='Command and any arguments to run')
args = parser.parse_args()

mode = args.mode if args.mode else 'container' if lib.utils.in_container() else 'host'

tmx_cmd = ['tmux', 'new-window']
if args.detach:
    tmx_cmd.append('-d')

CMD_STR = ' '.join(map(str, args.args))
if mode == 'container':
    CMD_STR = f"dbxe -- fish -c '{CMD_STR}'"
tmx_cmd.append(CMD_STR)

subprocess.run(tmx_cmd, check=True)
