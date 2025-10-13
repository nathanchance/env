#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position

parser = ArgumentParser(
    description='Run command in tmux with proper quoting to run in either host or container')
parser.add_argument('-c',
                    '--container',
                    action='store_const',
                    const='container',
                    dest='mode',
                    help='Run command in default development container')
parser.add_argument('-H',
                    '--host',
                    action='store_const',
                    const='host',
                    dest='mode',
                    help='Run command on the host')
parser.add_argument('-d', '--detach', action='store_true', help='Do not switch to created window')
parser.add_argument('-s',
                    '--split-horizontal',
                    action='store_const',
                    const=['split-window', '-v'],
                    dest='tmux_cmd',
                    help='Split command in a horizontal pane')
parser.add_argument('-v',
                    '--split-vertical',
                    action='store_const',
                    const=['split-window', '-H'],
                    dest='tmux_cmd',
                    help='Split command in a vertical pane')
parser.add_argument('cmd', help='Command and any arguments to run')
args = parser.parse_args()

if "'" in args.cmd:
    raise ValueError("Command cannot have ' in it!")

mode = args.mode if args.mode else 'container' if lib.utils.in_container() else 'host'

tmx_cmd = ['tmux']
if args.tmux_cmd:
    tmx_cmd += args.tmux_cmd
else:
    tmx_cmd.append('new-window')
if args.detach:
    tmx_cmd.append('-d')

if mode == 'container':
    cmd_str = f"sd_nspawn -r '{args.cmd}'; or exec fish -l"
else:
    cmd_str = f"begin; {args.cmd}; end; or exec fish -l"
tmx_cmd.append(cmd_str)

lib.utils.run(tmx_cmd)
